#include "core/exporter.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QProcess>
#include <QUrl>

#include "xlsxdocument.h"
#include "xlsxformat.h"
#include "xlsxworksheet.h"

#include "core/application_model.h"

namespace applycompass {

namespace {

// 状态配色（旧表条件格式实测值；与 qml/Theme.qml 同步，tst_ui 有锚定）
QString statusColorHex(const QString &status)
{
    static const QHash<QString, QString> kColors = {
        {QStringLiteral("初筛"), QStringLiteral("#E7E6E6")},
        {QStringLiteral("笔试"), QStringLiteral("#FFE699")},
        {QStringLiteral("面试"), QStringLiteral("#BDD7EE")},
        {QStringLiteral("Offer"), QStringLiteral("#C6EFCE")},
        {QStringLiteral("简历挂"), QStringLiteral("#FFC7CE")},
        {QStringLiteral("笔试挂"), QStringLiteral("#FFC7CE")},
        {QStringLiteral("面试挂"), QStringLiteral("#FFC7CE")},
        {QStringLiteral("挂"), QStringLiteral("#FFC7CE")},
        {QStringLiteral("放弃"), QStringLiteral("#D0CECE")},
    };
    return kColors.value(status);
}

const QStringList kHeaders = {
    QStringLiteral("公司"), QStringLiteral("岗位"), QStringLiteral("城市"),
    QStringLiteral("投递日期"), QStringLiteral("渠道"), QStringLiteral("状态"),
    QStringLiteral("状态更新"), QStringLiteral("简历版本"), QStringLiteral("跟进链接"),
    QStringLiteral("备注"), QStringLiteral("类型"), QStringLiteral("职责"),
    QStringLiteral("要求"), QStringLiteral("薪资"),
};
const QList<int> kColWidths = {22, 30, 16, 12, 8, 10, 12, 20, 34, 40, 6, 30, 30, 10};

QString isoOrEmpty(const QDate &d)
{
    return d.isValid() ? d.toString(Qt::ISODate) : QString();
}

QString csvField(QString s)
{
    s.replace(QLatin1Char('"'), QStringLiteral("\"\""));
    if (s.contains(QLatin1Char(',')) || s.contains(QLatin1Char('"'))
        || s.contains(QLatin1Char('\n')) || s.contains(QLatin1Char('\r'))) {
        return QLatin1Char('"') + s + QLatin1Char('"');
    }
    return s;
}

QStringList recordCells(const ApplicationRecord &r)
{
    return {r.company, r.position, r.region, isoOrEmpty(r.applyDate), r.channel,
            r.status, isoOrEmpty(r.statusUpdated), r.resumeVersion, r.link, r.notes,
            r.kind, r.duties, r.requirements, r.salary};
}

// 冻结前两行：QXlsx 1.5.1.1 无 API，保存后对 xlsx 做 ZIP 注入（unzip → 补 <pane> → zip）。
// 失败时恢复原文件并返回 false（调用方降级为不冻结）。
bool injectFreezePanes(const QString &xlsxPath, QString *warning)
{
    const QString workDir = QDir::tempPath() + QStringLiteral("/applycompass_freeze_work");
    const QString outZip = QDir::tempPath() + QStringLiteral("/applycompass_freeze_out.xlsx");
    QDir(workDir).removeRecursively();
    if (!QDir().mkpath(workDir)) {
        *warning = QStringLiteral("冻结注入失败：无法创建临时目录");
        return false;
    }
    QFile::remove(outZip);

    auto run = [](const QString &program, const QStringList &args, const QString &cwd) {
        QProcess p;
        p.setWorkingDirectory(cwd);
        p.start(program, args);
        p.waitForFinished(30000);
        return p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
    };

    if (!run(QStringLiteral("unzip"), {QStringLiteral("-o"), QStringLiteral("-q"), xlsxPath,
                                       QStringLiteral("-d"), workDir}, QDir::tempPath())) {
        *warning = QStringLiteral("冻结注入跳过：unzip 不可用");
        return false;
    }

    const QString sheetPath = workDir + QStringLiteral("/xl/worksheets/sheet1.xml");
    QFile sheet(sheetPath);
    if (!sheet.open(QIODevice::ReadOnly)) {
        *warning = QStringLiteral("冻结注入失败：未找到工作表 XML");
        return false;
    }
    QString xml = QString::fromUtf8(sheet.readAll());
    sheet.close();

    // 定位 <sheetView ...> 单数元素（注意勿命中复数容器 <sheetViews>）
    int viewIdx = xml.indexOf(QStringLiteral("<sheetView "));
    if (viewIdx < 0)
        viewIdx = xml.indexOf(QStringLiteral("<sheetView>"));
    if (viewIdx < 0) {
        *warning = QStringLiteral("冻结注入失败：无 sheetView 节点");
        return false;
    }
    const int tagEnd = xml.indexOf(QLatin1Char('>'), viewIdx);
    if (tagEnd < 1) {
        *warning = QStringLiteral("冻结注入失败：sheetView 结构异常");
        return false;
    }
    const QString pane = QStringLiteral(
        "<pane ySplit=\"2\" topLeftCell=\"A3\" activePane=\"bottomLeft\" state=\"frozen\"/>");
    if (xml.at(tagEnd - 1) == QLatin1Char('/')) {
        // 自闭合 <sheetView .../> → 展开为成对并插入 pane（Excel 语义要求 pane 在 sheetView 内）
        xml.replace(tagEnd - 1, 2,
                    QLatin1Char('>') + pane + QStringLiteral("</sheetView>"));
    } else {
        xml.insert(tagEnd + 1, pane);
    }

    if (!sheet.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        *warning = QStringLiteral("冻结注入失败：工作表不可写");
        return false;
    }
    sheet.write(xml.toUtf8());
    sheet.close();

    if (!run(QStringLiteral("zip"), {QStringLiteral("-X"), QStringLiteral("-r"), QStringLiteral("-q"),
                                     outZip, QStringLiteral(".")}, workDir)) {
        *warning = QStringLiteral("冻结注入失败：zip 打包失败");
        return false;
    }

    // 原文件先备份，注入件读回自检通过后替换
    const QString backup = xlsxPath + QStringLiteral(".prefreeze.bak");
    QFile::remove(backup);
    if (!QFile::copy(xlsxPath, backup)) {
        *warning = QStringLiteral("冻结注入失败：无法备份原文件");
        return false;
    }
    QFile::remove(xlsxPath);
    if (!QFile::copy(outZip, xlsxPath)) {
        QFile::copy(backup, xlsxPath);
        QFile::remove(backup);
        *warning = QStringLiteral("冻结注入失败：替换文件失败");
        return false;
    }

    QXlsx::Document verify(xlsxPath);
    if (!verify.load()) {
        QFile::remove(xlsxPath);
        QFile::copy(backup, xlsxPath); // 回滚
        QFile::remove(backup);
        *warning = QStringLiteral("冻结注入失败：注入后文件读取自检未通过，已回滚");
        return false;
    }
    QFile::remove(backup);
    return true;
}

} // namespace

ExportResult Exporter::exportAll(Database &db, const QString &outputDir, const QDate &today)
{
    ExportResult result;
    if (!db.isOpen()) {
        result.error = QStringLiteral("数据库未打开");
        return result;
    }
    const QVector<ApplicationRecord> records = db.loadAll(); // 已投（进入顺序）→ 待投

    // 统计（全库口径同 §3.1）
    int totalApplied = 0, inProgress = 0, rejected = 0, offers = 0, followUp = 0;
    for (const ApplicationRecord &r : records) {
        if (!r.isApplied())
            continue;
        ++totalApplied;
        if (enums::InProgressStatuses.contains(r.status))
            ++inProgress;
        if (enums::RejectedStatuses.contains(r.status))
            ++rejected;
        if (r.status == enums::Offer)
            ++offers;
        if (ApplicationModel::isFollowUpDue(r, today))
            ++followUp;
    }

    QDir outDir(outputDir);
    if (!outDir.exists() && !QDir().mkpath(outputDir)) {
        result.error = QStringLiteral("无法创建导出目录：%1").arg(outputDir);
        return result;
    }
    const QString base = QStringLiteral("投递罗盘_%1").arg(today.toString(Qt::ISODate));
    result.xlsxPath = outDir.filePath(base + QStringLiteral(".xlsx"));
    result.csvPath = outDir.filePath(base + QStringLiteral(".csv"));

    // ---------------- xlsx ----------------
    {
        QXlsx::Document doc;
        // 新 Document 首次写入前可能没有工作表：显式创建，保证表名固定
        if (doc.sheetNames().isEmpty())
            doc.addSheet(QStringLiteral("投递记录"));
        else if (!doc.renameSheet(doc.sheetNames().first(), QStringLiteral("投递记录"))) {
            result.error = QStringLiteral("导出失败：工作表重命名失败");
            return result;
        }
        QXlsx::Worksheet *sheet = doc.currentWorksheet();
        if (!sheet) {
            result.error = QStringLiteral("导出失败：无法获取工作表");
            return result;
        }

        const QString statLine =
            QStringLiteral("投递记录 · 投递罗盘导出 · %1 ｜ 总投递 %2 ｜ 进行中 %3 ｜ 已挂 %4 ｜ "
                           "Offer %5 ｜ 待跟进 %6")
                .arg(today.toString(Qt::ISODate))
                .arg(totalApplied).arg(inProgress).arg(rejected).arg(offers).arg(followUp);
        QXlsx::Format statFormat;
        statFormat.setFontBold(true);
        doc.write(1, 1, statLine, statFormat);

        QXlsx::Format headFormat;
        headFormat.setFontBold(true);
        headFormat.setPatternForegroundColor(QColor(QStringLiteral("#F2F4F7")));
        headFormat.setPatternBackgroundColor(QColor(QStringLiteral("#F2F4F7")));
        headFormat.setFillPattern(QXlsx::Format::PatternSolid);
        for (int c = 0; c < kHeaders.size(); ++c)
            doc.write(2, c + 1, kHeaders.at(c), headFormat);

        int row = 3;
        for (const ApplicationRecord &r : records) {
            // 状态整行浅色（§3.4 旧表实测值；与原表观感一致）
            QXlsx::Format rowFormat;
            const QString statusColor = statusColorHex(r.status);
            if (!statusColor.isEmpty()) {
                rowFormat.setPatternForegroundColor(QColor(statusColor));
                rowFormat.setPatternBackgroundColor(QColor(statusColor));
                rowFormat.setFillPattern(QXlsx::Format::PatternSolid);
            }
            const QStringList cells = recordCells(r);
            for (int c = 0; c < cells.size(); ++c) {
                const int col = c + 1;
                if ((col == 4 || col == 7)) { // 投递日期 / 状态更新
                    if (r.applyDate.isValid() || r.statusUpdated.isValid()) {
                        const QDate d = (col == 4) ? r.applyDate : r.statusUpdated;
                        if (d.isValid())
                            sheet->writeDate(row, col, d, rowFormat);
                    }
                    continue;
                }
                if (col == 9) // 跟进链接：可点超链接
                    continue;
                doc.write(row, col, cells.at(c), rowFormat);
            }
            if (!r.link.isEmpty()) {
                QXlsx::Format linkFormat = rowFormat;
                linkFormat.setFontColor(QColor(QStringLiteral("#0563C1")));
                linkFormat.setFontUnderline(QXlsx::Format::FontUnderlineSingle);
                sheet->writeHyperlink(row, 9, QUrl(r.link), linkFormat);
            }
            ++row;
        }

        for (int c = 0; c < kColWidths.size(); ++c)
            sheet->setColumnWidth(c + 1, c + 1, kColWidths.at(c));

        if (!doc.saveAs(result.xlsxPath)) {
            result.error = QStringLiteral("导出失败：xlsx 写入失败");
            return result;
        }
    }

    // 冻结前两行（非致命）
    QString freezeWarning;
    if (!injectFreezePanes(result.xlsxPath, &freezeWarning) && !freezeWarning.isEmpty())
        result.warning = freezeWarning;

    // ---------------- csv（UTF-8 BOM + CRLF） ----------------
    {
        QFile csv(result.csvPath);
        if (!csv.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            result.error = QStringLiteral("导出失败：CSV 写入失败");
            return result;
        }
        csv.write("\xEF\xBB\xBF"); // BOM
        QStringList lines;
        lines.reserve(records.size() + 1);
        lines << kHeaders.join(QLatin1Char(','));
        for (const ApplicationRecord &r : records) {
            const QStringList cells = recordCells(r);
            QStringList out;
            out.reserve(cells.size());
            for (const QString &f : cells)
                out << csvField(f);
            lines << out.join(QLatin1Char(','));
        }
        csv.write(lines.join(QStringLiteral("\r\n")).toUtf8());
        csv.write("\r\n");
        csv.close();
    }

    return result;
}

} // namespace applycompass
