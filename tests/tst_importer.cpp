#include <QtTest>

#include <QTemporaryDir>
#include <memory>

#include "core/database.h"
#include "core/legacy_importer.h"

using namespace applycompass;

// 旧表导入单测：序列号换算钉死 + 真文件只读全量导入断言（43 条 / 12+31 / 跳过宏测试行）。
class TstImporter : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    void excelSerialConversion();
    void importRealXlsm();

private:
    std::unique_ptr<QTemporaryDir> m_tmp;
    std::unique_ptr<Database> m_db;
};

void TstImporter::init()
{
    m_tmp = std::make_unique<QTemporaryDir>();
    QVERIFY(m_tmp->isValid());
    m_db = std::make_unique<Database>(m_tmp->path());
    QString err;
    QVERIFY2(m_db->open(&err), qPrintable(err));
}

void TstImporter::cleanup()
{
    m_db.reset();
    m_tmp.reset();
}

void TstImporter::excelSerialConversion()
{
    // 回归锚点：QXlsx Cell::dateTime() 对 46305 会差一天给出 2026-10-09，
    // 正确值为 2026-10-10（openpyxl 实测 D3）；不得回退到 QXlsx 的转换。
    QCOMPARE(LegacyImporter::excelSerialToDate(46305), QDate(2026, 10, 10));
    QCOMPARE(LegacyImporter::excelSerialToDate(46306), QDate(2026, 10, 11));
    QCOMPARE(LegacyImporter::excelSerialToDate(46309), QDate(2026, 10, 14));
    QCOMPARE(LegacyImporter::excelSerialToDate(46305.75), QDate(2026, 10, 10)); // 带时间只取日期
    QVERIFY(!LegacyImporter::excelSerialToDate(0).isValid());
    QVERIFY(!LegacyImporter::excelSerialToDate(-3).isValid());
}

void TstImporter::importRealXlsm()
{
    const QString path = QStringLiteral(APPLYCOMPASS_LEGACY_XLSM);
    if (!QFile::exists(path))
        QSKIP("旧表文件不存在（本机专有路径），跳过");

    const ImportSummary s = LegacyImporter::importFromXlsm(path, *m_db);
    QVERIFY2(s.error.isEmpty(), qPrintable(s.error));
    QCOMPARE(s.imported, 43);
    QCOMPARE(s.skipped, 1); // 【宏测试行】
    QCOMPARE(m_db->recordCount(), qint64(43));

    const QVector<ApplicationRecord> all = m_db->loadAll();
    QCOMPARE(all.size(), 43);

    int applied = 0;
    for (const ApplicationRecord &r : all) {
        if (r.isApplied())
            ++applied;
        QVERIFY(!r.company.contains(QStringLiteral("宏测试行")));
    }
    QCOMPARE(applied, 12);        // 行 3–14 已投
    QCOMPARE(all.size() - applied, 31); // 行 15–45 待投（25+6 实习候选）

    // 已投区顺序 = 源行序
    QCOMPARE(all.at(0).company, QStringLiteral("成都星岚数码科技"));
    QCOMPARE(all.at(0).applyDate, QDate(2026, 10, 10));
    QCOMPARE(all.at(0).status, QStringLiteral("初筛"));
    QCOMPARE(all.at(0).channel, QStringLiteral("官网"));
    QCOMPARE(all.at(0).kind, QStringLiteral("正式"));
    QCOMPARE(all.at(11).company, QStringLiteral("云杉科技（成都研究所）"));

    // 待投区首条 = 源行 15（明图）；全部无状态、无日期
    QCOMPARE(all.at(12).company, QStringLiteral("明图集团"));
    QVERIFY(all.at(12).status.isEmpty());
    QVERIFY(all.at(12).applyDate.isNull());
    for (int i = 12; i < all.size(); ++i) {
        QVERIFY(all.at(i).status.isEmpty());
        QVERIFY(all.at(i).applyDate.isNull());
    }

    // sort_index 连续 1..43
    QCOMPARE(all.first().sortIndex, qint64(1));
    QCOMPARE(all.last().sortIndex, qint64(43));

    auto find = [&all](const QString &company, const QString &posPart = {}) -> ApplicationRecord {
        for (const ApplicationRecord &r : all) {
            if (r.company == company
                && (posPart.isEmpty() || r.position.contains(posPart)))
                return r;
        }
        return {};
    };

    // 类型启发（§4.3）
    QCOMPARE(find(QStringLiteral("星禾科技")).kind, QStringLiteral("实习"));   // 行 40–45
    QCOMPARE(find(QStringLiteral("明川科技"), QStringLiteral("（实习）")).kind,
             QStringLiteral("实习"));                                          // 行 44 区间 + 备注
    QCOMPARE(find(QStringLiteral("云启智联")).kind, QStringLiteral("正式"));
    QCOMPARE(find(QStringLiteral("光年互联"), QStringLiteral("实习生")).kind,
             QStringLiteral("实习"));                                          // 备注含"实习"
    QCOMPARE(find(QStringLiteral("远望软件")).kind, QStringLiteral("正式"));

    // 日期与多行备注抽查
    QCOMPARE(find(QStringLiteral("青桥通信")).applyDate, QDate(2026, 10, 14));
    QVERIFY(find(QStringLiteral("云杉科技（成都研究所）")).notes.contains(QLatin1Char('\n')));

    // 关联性：导入不产生时间线事件（不编造历史）
    for (const ApplicationRecord &r : all)
        QCOMPARE(m_db->statusEvents(r.id).size(), 0);
}

QTEST_GUILESS_MAIN(TstImporter)

#include "tst_importer.moc"
