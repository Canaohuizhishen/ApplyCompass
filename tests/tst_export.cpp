#include <QtTest>

#include <QProcess>
#include <QTemporaryDir>
#include <memory>

#include "core/database.h"
#include "core/exporter.h"
#include "xlsxcell.h"
#include "xlsxdocument.h"
#include "xlsxformat.h"
#include "xlsxworksheet.h"

using namespace applycompass;

// 导出单测：xlsx 内容/配色/统计 读回断言；CSV 的 BOM 与引号转义；冻结 pane 注入检查。
class TstExport : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    void exportContents();
    void csvBytesAndQuoting();
    void freezePaneInjected();

private:
    qint64 seed(const QString &company, const QString &status, const QDate &date, qint64 sort,
                const QString &link = QString(), const QString &notes = QString(),
                const QString &salary = QString());

    std::unique_ptr<QTemporaryDir> m_tmp;
    std::unique_ptr<Database> m_db;
    QString m_exportDir;
};

void TstExport::init()
{
    m_tmp = std::make_unique<QTemporaryDir>();
    QVERIFY(m_tmp->isValid());
    m_exportDir = m_tmp->filePath(QStringLiteral("导出/深层目录"));
    m_db = std::make_unique<Database>(m_tmp->filePath(QStringLiteral("data")));
    QString err;
    QVERIFY2(m_db->open(&err), qPrintable(err));
}

void TstExport::cleanup()
{
    m_db.reset();
    m_tmp.reset();
}

qint64 TstExport::seed(const QString &company, const QString &status, const QDate &date,
                       qint64 sort, const QString &link, const QString &notes,
                       const QString &salary)
{
    ApplicationRecord r;
    r.company = company;
    r.position = QStringLiteral("岗位");
    r.status = status;
    r.statusUpdated = date;
    r.applyDate = date;
    r.sortIndex = sort;
    r.link = link;
    r.notes = notes;
    r.salary = salary;
    r.channel = QStringLiteral("官网");
    r.resumeVersion = QStringLiteral("C++服务端开发");
    return m_db->insertRecord(r);
}

void TstExport::exportContents()
{
    const QDate today = QDate::currentDate();
    seed(QStringLiteral("甲科技"), QStringLiteral("初筛"), today, 1,
         QStringLiteral("https://example.com/job/1"));
    seed(QStringLiteral("乙网络"), QStringLiteral("Offer"), today, 2, QString(),
         QString(), QStringLiteral("25×16"));
    seed(QStringLiteral("丙软件"), QString(), QDate(), 3);

    const ExportResult res = Exporter::exportAll(*m_db, m_exportDir, today);
    QVERIFY2(res.ok(), qPrintable(res.error));
    QVERIFY(QFile::exists(res.xlsxPath));
    QVERIFY(QFile::exists(res.csvPath));

    QXlsx::Document doc(res.xlsxPath);
    QVERIFY(doc.load());
    auto *sheet = dynamic_cast<QXlsx::Worksheet *>(doc.sheet(QStringLiteral("投递记录")));
    QVERIFY(sheet != nullptr);

    // 顶部统计：总投递 2（甲+乙）、Offer 1
    const QString stat = sheet->cellAt(1, 1)->value().toString();
    QVERIFY(stat.contains(QStringLiteral("总投递 2")));
    QVERIFY(stat.contains(QStringLiteral("Offer 1")));

    // 表头（原表列序 + 新列）
    QCOMPARE(sheet->cellAt(2, 1)->value().toString(), QStringLiteral("公司"));
    QCOMPARE(sheet->cellAt(2, 10)->value().toString(), QStringLiteral("备注"));
    QCOMPARE(sheet->cellAt(2, 11)->value().toString(), QStringLiteral("类型"));
    QCOMPARE(sheet->cellAt(2, 14)->value().toString(), QStringLiteral("薪资"));

    // 数据行（已投在前：甲、乙；待投：丙）
    QCOMPARE(sheet->cellAt(3, 1)->value().toString(), QStringLiteral("甲科技"));
    QCOMPARE(sheet->cellAt(3, 6)->value().toString(), QStringLiteral("初筛"));
    QCOMPARE(sheet->cellAt(4, 1)->value().toString(), QStringLiteral("乙网络"));
    QCOMPARE(sheet->cellAt(4, 14)->value().toString(), QStringLiteral("25×16"));
    QCOMPARE(sheet->cellAt(5, 1)->value().toString(), QStringLiteral("丙软件"));

    // 日期写为日期型：读回是 QDate 或序列号 double 两种形态，均按真实日期断言
    const QVariant d3 = sheet->cellAt(3, 4)->value();
    QDate readDate = d3.canConvert<QDate>() && d3.toDate().isValid()
                         ? d3.toDate()
                         : QDate(1899, 12, 30).addDays(d3.toLongLong());
    QCOMPARE(readDate, today);

    // 状态整行配色（旧表实测值：初筛 #E7E6E6 / Offer #C6EFCE）
    QCOMPARE(sheet->cellAt(3, 1)->format().patternBackgroundColor().name().toUpper(),
             QStringLiteral("#E7E6E6"));
    QCOMPARE(sheet->cellAt(4, 1)->format().patternBackgroundColor().name().toUpper(),
             QStringLiteral("#C6EFCE"));
}

void TstExport::csvBytesAndQuoting()
{
    const QDate today = QDate::currentDate();
    seed(QStringLiteral("含逗号,公司"), QStringLiteral("初筛"), today, 1, QString(),
         QStringLiteral("备注含\"引号\"\n第二行"));

    const ExportResult res = Exporter::exportAll(*m_db, m_exportDir, today);
    QVERIFY2(res.ok(), qPrintable(res.error));

    QFile csv(res.csvPath);
    QVERIFY(csv.open(QIODevice::ReadOnly));
    const QByteArray bytes = csv.readAll();
    csv.close();

    // UTF-8 BOM
    QVERIFY(bytes.startsWith(QByteArray("\xEF\xBB\xBF")));
    const QString text = QString::fromUtf8(bytes.mid(3));
    // 引号转义 + 内嵌换行保留
    QVERIFY(text.contains(QStringLiteral("\"含逗号,公司\"")));
    QVERIFY(text.contains(QStringLiteral("\"备注含\"\"引号\"\"\n第二行\"")));
    // 表头 + 1 行数据 + 行尾 CRLF
    QCOMPARE(text.count(QStringLiteral("\r\n")), 2);
    QVERIFY(text.startsWith(QStringLiteral("公司,岗位,城市")));
}

void TstExport::freezePaneInjected()
{
    if (QProcess::execute(QStringLiteral("which"), {QStringLiteral("unzip")}) != 0)
        QSKIP("unzip 不可用，跳过");

    seed(QStringLiteral("冻结公司"), QStringLiteral("初筛"), QDate::currentDate(), 1);
    const ExportResult res = Exporter::exportAll(*m_db, m_exportDir);
    QVERIFY2(res.ok(), qPrintable(res.error));
    QVERIFY(res.warning.isEmpty()); // 本机 zip/unzip 齐备，注入应成功

    QProcess p;
    p.start(QStringLiteral("unzip"), {QStringLiteral("-p"), res.xlsxPath,
                                      QStringLiteral("xl/worksheets/sheet1.xml")});
    QVERIFY(p.waitForFinished(30000));
    const QByteArray xml = p.readAllStandardOutput();
    QVERIFY(xml.contains("topLeftCell=\"A3\""));
    QVERIFY(xml.contains("state=\"frozen\""));
    // pane 必须位于 <sheetView> 单数元素之内（回归锚点：曾误注入 <sheetViews> 容器之下）
    const int viewsIdx = xml.indexOf("<sheetViews>");
    const int viewIdx = xml.indexOf("<sheetView ", viewsIdx);
    const int paneIdx = xml.indexOf("<pane", viewsIdx);
    QVERIFY(viewsIdx >= 0);
    QVERIFY(viewIdx > viewsIdx);
    QVERIFY(paneIdx > viewIdx);
}

QTEST_GUILESS_MAIN(TstExport)

#include "tst_export.moc"
