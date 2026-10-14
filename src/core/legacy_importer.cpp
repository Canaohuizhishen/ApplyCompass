#include "core/legacy_importer.h"

#include "xlsxcell.h"
#include "xlsxdocument.h"
#include "xlsxworksheet.h"

namespace applycompass {

QDate LegacyImporter::excelSerialToDate(double serial)
{
    if (serial <= 0)
        return {};
    return QDate(1899, 12, 30).addDays(qint64(serial));
}

ImportSummary LegacyImporter::importFromXlsm(const QString &xlsmPath, Database &db)
{
    ImportSummary summary;
    if (!db.isOpen()) {
        summary.error = QStringLiteral("数据库未打开");
        return summary;
    }

    QXlsx::Document doc(xlsmPath);
    if (!doc.load()) {
        summary.error = QStringLiteral("无法读取文件：%1").arg(xlsmPath);
        return summary;
    }
    auto *sheet = dynamic_cast<QXlsx::Worksheet *>(doc.sheet(QStringLiteral("投递记录")));
    if (!sheet) {
        summary.error = QStringLiteral("未找到工作表「投递记录」");
        return summary;
    }

    auto cellText = [sheet](int row, int col) -> QString {
        const auto cell = sheet->cellAt(row, col);
        return cell ? cell->value().toString().trimmed() : QString();
    };
    auto cellDate = [sheet](int row, int col) -> QDate {
        const auto cell = sheet->cellAt(row, col);
        if (!cell)
            return {};
        const QVariant v = cell->value();
        const int type = v.metaType().id();
        if (type == QMetaType::Double || type == QMetaType::Int || type == QMetaType::LongLong)
            return excelSerialToDate(v.toDouble()); // 实测旧表 D/G 列为序列号 double
        if (v.canConvert<QDate>())
            return v.toDate();
        const QString s = v.toString().trimmed();
        if (s.isEmpty())
            return {};
        QDate d = QDate::fromString(s, Qt::ISODate);
        if (!d.isValid() && s.size() >= 10)
            d = QDate::fromString(s.left(10), Qt::ISODate); // "2026-10-10 00:00:00" 形态
        return d;
    };

    const int lastRow = sheet->dimension().lastRow();
    qint64 sortIndex = 0;
    for (int row = 3; row <= lastRow; ++row) { // 行 1 标题、行 2 表头
        const QString company = cellText(row, 1);
        if (company.isEmpty())
            continue;
        if (company.contains(QStringLiteral("宏测试行"))) { // 行 46 测试行：跳过
            ++summary.skipped;
            continue;
        }

        ApplicationRecord rec;
        rec.company = company;
        rec.position = cellText(row, 2);
        rec.region = cellText(row, 3);
        rec.applyDate = cellDate(row, 4);
        rec.channel = cellText(row, 5);
        rec.status = cellText(row, 6);
        rec.statusUpdated = cellDate(row, 7);
        rec.resumeVersion = cellText(row, 8);
        rec.link = cellText(row, 9);
        rec.notes = cellText(row, 10);
        // 类型启发（设计文档 §4.3）：备注含"实习"或源行 40–45（实习候选）→ 实习
        rec.kind = (rec.notes.contains(QStringLiteral("实习")) || (row >= 40 && row <= 45))
                       ? QStringLiteral("实习")
                       : QStringLiteral("正式");
        rec.sortIndex = ++sortIndex; // 源行序 → 区内顺序（已投 12 在前、待投 31 在后）

        if (db.insertRecord(rec) < 0) {
            summary.error = db.lastError();
            return summary;
        }
        ++summary.imported;
    }
    return summary;
}

} // namespace applycompass
