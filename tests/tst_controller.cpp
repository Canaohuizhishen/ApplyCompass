#include <QtTest>

#include <QGuiApplication>
#include <QTemporaryDir>

#include "app_controller.h"
#include "core/database.h"

using namespace applycompass;

// AppController 启动逻辑回归（M5）：
// 主题偏好从 settings 读入后必须立即生效——历史 bug：initDarkMode() 的首次重算
// 发生在偏好读入之前（其时仍为默认 system），读入后未重算 → 启动忽略用户偏好
//（症状：设置选浅色，重启仍是系统深色）。
class TstController : public QObject
{
    Q_OBJECT

private slots:
    void themePreferenceAppliedAtStartup_data();
    void themePreferenceAppliedAtStartup();

    void themePreferenceRoundtripAcrossRestart();

private:
    // 准备隔离数据目录并预写 theme 键；返回后可构造 AppController
    static bool prepareDataDir(const QTemporaryDir &dir, const QString &theme)
    {
        qputenv("APPLYCOMPASS_DATA_DIR", dir.path().toLocal8Bit());
        Database db(dir.path());
        QString err;
        if (!db.open(&err))
            return false;
        return theme.isEmpty() ? true : db.setSetting(QStringLiteral("theme"), theme);
    }
};

void TstController::themePreferenceAppliedAtStartup_data()
{
    QTest::addColumn<QString>("theme");
    QTest::addColumn<QString>("expectedPref");
    QTest::newRow("light 偏好启动即浅色") << "light" << "light";
    QTest::newRow("dark 偏好启动即深色") << "dark" << "dark";
    QTest::newRow("非法值回退 system") << "banana" << "system";
}

void TstController::themePreferenceAppliedAtStartup()
{
    QFETCH(QString, theme);
    QFETCH(QString, expectedPref);

    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(prepareDataDir(dir, theme));

    AppController ctrl;
    QCOMPARE(ctrl.themePreference(), expectedPref);
    // 显式偏好必须覆盖系统色（本机系统为深色 → light 行可捕获历史 bug；
    // system 行不在此断言具体明暗，由环境决定）
    if (expectedPref == QLatin1String("light"))
        QVERIFY(!ctrl.darkMode());
    else if (expectedPref == QLatin1String("dark"))
        QVERIFY(ctrl.darkMode());
}

void TstController::themePreferenceRoundtripAcrossRestart()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(prepareDataDir(dir, QString()));

    {
        AppController ctrl; // “第一个会话”：改偏好
        QCOMPARE(ctrl.themePreference(), QStringLiteral("system"));
        ctrl.setThemePreference(QStringLiteral("dark"));
        QVERIFY(ctrl.darkMode());
    }

    {
        AppController ctrl; // “重启”：同一数据目录，新实例读回偏好并立即生效
        QCOMPARE(ctrl.themePreference(), QStringLiteral("dark"));
        QVERIFY(ctrl.darkMode());
    }

    {
        AppController ctrl; // 再改回浅色，重启验证两向
        ctrl.setThemePreference(QStringLiteral("light"));
    }
    {
        AppController ctrl;
        QCOMPARE(ctrl.themePreference(), QStringLiteral("light"));
        QVERIFY(!ctrl.darkMode());
    }
}

QTEST_MAIN(TstController)

#include "tst_controller.moc"
