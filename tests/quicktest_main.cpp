// QuickTest 入口（qmltestrunner 等价物）：链入 applycompass_ui 静态模块，
// 在引擎加载测试文件前把数据目录指向临时目录（保证测试不碰真实数据）。
#include <QDir>
#include <QObject>
#include <QQmlEngine>
#include <QtQuickTest/quicktest.h>

class ApplyCompassTestSetup : public QObject
{
    Q_OBJECT

public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        Q_UNUSED(engine);
        const QString dir = QDir::current().filePath(QStringLiteral("tst_ui_data"));
        QDir(dir).removeRecursively();
        QDir().mkpath(dir);
        qputenv("APPLYCOMPASS_DATA_DIR", dir.toLocal8Bit());
    }
};

QUICK_TEST_MAIN_WITH_SETUP(tst_ui, ApplyCompassTestSetup)

#include "quicktest_main.moc"
