#include <QtTest>

#include <QTemporaryDir>
#include <memory>

#include "core/application_model.h"
#include "core/database.h"

using namespace applycompass;

// 模型层单测：待跟进边界（>14 天）、筛选双口径（统计全库 / 可见计数）。
class TstModel : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    void followUpDueBoundary();
    void filtersAndCounts();
    void tsvTextFormat();

private:
    std::unique_ptr<QTemporaryDir> m_tmp;
    std::unique_ptr<Database> m_db;
};

void TstModel::init()
{
    m_tmp = std::make_unique<QTemporaryDir>();
    QVERIFY(m_tmp->isValid());
    m_db = std::make_unique<Database>(m_tmp->path());
    QString err;
    QVERIFY2(m_db->open(&err), qPrintable(err));
}

void TstModel::cleanup()
{
    m_db.reset();
    m_tmp.reset();
}

static qint64 seed(Database &db, const QString &company, const QString &status,
                   const QDate &updated, qint64 sort, const QString &region = QString())
{
    ApplicationRecord r;
    r.company = company;
    r.position = QStringLiteral("p");
    r.status = status;
    r.statusUpdated = updated;
    r.region = region;
    r.sortIndex = sort;
    return db.insertRecord(r);
}

void TstModel::followUpDueBoundary()
{
    const QDate today = QDate::currentDate();
    seed(*m_db, QStringLiteral("old16"), QStringLiteral("初筛"), today.addDays(-16), 1);
    seed(*m_db, QStringLiteral("old15"), QStringLiteral("初筛"), today.addDays(-15), 2);
    seed(*m_db, QStringLiteral("exact14"), QStringLiteral("初筛"), today.addDays(-14), 3);
    seed(*m_db, QStringLiteral("recent"), QStringLiteral("初筛"), today.addDays(-3), 4);
    seed(*m_db, QStringLiteral("other"), QStringLiteral("面试"), today.addDays(-30), 5);

    ApplicationModel model(m_db.get());
    QCOMPARE(model.followUpDue(), 2); // old16 + old15（15 天 > 14 算；刚好 14 不算）

    ApplicationRecord r;
    r.status = QStringLiteral("初筛");
    r.statusUpdated = today.addDays(-15);
    QVERIFY(ApplicationModel::isFollowUpDue(r, today));
    r.statusUpdated = today.addDays(-14);
    QVERIFY(!ApplicationModel::isFollowUpDue(r, today));
    r.statusUpdated = QDate();
    QVERIFY(!ApplicationModel::isFollowUpDue(r, today));
    r.status = QStringLiteral("Offer");
    r.statusUpdated = today.addDays(-30);
    QVERIFY(!ApplicationModel::isFollowUpDue(r, today)); // 仅初筛
}

void TstModel::filtersAndCounts()
{
    const QDate today = QDate::currentDate();
    seed(*m_db, QStringLiteral("甲科技"), QStringLiteral("初筛"), today, 1, QStringLiteral("成都"));
    seed(*m_db, QStringLiteral("乙网络"), QString(), QDate(), 2, QStringLiteral("北京"));
    seed(*m_db, QStringLiteral("丙软件"), QStringLiteral("Offer"), today, 3, QStringLiteral("成都"));

    ApplicationModel model(m_db.get());
    QCOMPARE(model.count(), 3);
    QCOMPARE(model.regionOptions().size(), 2);

    // 搜索（中文子串）
    model.setSearchText(QStringLiteral("网"));
    QCOMPARE(model.count(), 1);
    QCOMPARE(model.recordAtRow(0).value(QStringLiteral("company")).toString(),
             QStringLiteral("乙网络"));
    model.setSearchText(QString());

    // 待跟进筛选（本批无 >14 天）
    model.setFollowUpOnly(true);
    QCOMPARE(model.count(), 0);
    QVERIFY(model.filtersActive());
    model.setFollowUpOnly(false);

    // 状态多选 + 双口径
    model.setStatusFilter({QStringLiteral("初筛"), QStringLiteral("Offer")});
    QCOMPARE(model.count(), 2);
    QCOMPARE(model.totalApplied(), 2);        // 全库口径
    QCOMPARE(model.visibleAppliedCount(), 2); // 可见口径
    QCOMPARE(model.visiblePendingCount(), 0);

    // 清除恢复
    model.clearFilters();
    QCOMPARE(model.count(), 3);
    QCOMPARE(model.visiblePendingCount(), 1);
    QVERIFY(!model.filtersActive());

    // 地区 + 类型叠加
    model.setRegionFilter(QStringLiteral("成都"));
    model.setKindFilter(QStringLiteral("正式")); // 数据 kind 均为空 → 无匹配
    QCOMPARE(model.count(), 0);
    model.setKindFilter(QString());
    QCOMPARE(model.count(), 2);
}

// 选中行 TSV（Ctrl+C 复制，M3）：表头、范围钳制/交换、单元格净化
void TstModel::tsvTextFormat()
{
    ApplicationRecord r1;
    r1.company = QStringLiteral("甲科技");
    r1.position = QStringLiteral("后端");
    r1.kind = QStringLiteral("实习");
    r1.region = QStringLiteral("成都");
    r1.applyDate = QDate(2026, 10, 1);
    r1.channel = QStringLiteral("BOSS");
    r1.status = QStringLiteral("初筛");
    r1.statusUpdated = QDate(2026, 10, 2);
    r1.resumeVersion = QStringLiteral("C++服务端开发");
    r1.link = QStringLiteral("https://a.example/\nb"); // 含换行 → 净化
    r1.sortIndex = 1;
    QVERIFY(m_db->insertRecord(r1) > 0);

    ApplicationRecord r2; // 待投
    r2.company = QStringLiteral("乙网络");
    r2.position = QStringLiteral("客户端");
    r2.sortIndex = 2;
    QVERIFY(m_db->insertRecord(r2) > 0);

    ApplicationModel model(m_db.get());
    QCOMPARE(model.count(), 2); // 已投区在前

    const QString tsv = model.tsvText(0, 1);
    const QStringList lines = tsv.split(QLatin1Char('\n'));
    QCOMPARE(lines.size(), 3);
    QCOMPARE(lines.at(0), QStringLiteral(
                            "公司\t岗位\t类型\t地区\t投递日期\t渠道\t状态\t状态更新\t简历版本\t链接"));
    QCOMPARE(lines.at(1), QStringLiteral(
                            "甲科技\t后端\t实习\t成都\t2026-10-01\tBOSS\t初筛\t2026-10-02"
                            "\tC++服务端开发\thttps://a.example/ b"));
    QVERIFY(!lines.at(1).contains(QLatin1Char('\r')));
    QVERIFY(lines.at(2).startsWith(QStringLiteral("乙网络\t客户端")));
    QVERIFY(lines.at(2).contains(QStringLiteral("\t\t"))); // 空列留空（待投行多列空）

    // 区间：交换端、越界钳制、完全越界 → 空
    QCOMPARE(model.tsvText(1, 0), model.tsvText(0, 1));
    QCOMPARE(model.tsvText(0, 99).split(QLatin1Char('\n')).size(), 3);
    QCOMPARE(model.tsvText(5, 9), QString());
}

QTEST_GUILESS_MAIN(TstModel)
#include "tst_model.moc"
