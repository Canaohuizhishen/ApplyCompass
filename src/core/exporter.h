#pragma once

#include <QDate>
#include <QString>

#include "core/database.h"

namespace applycompass {

struct ExportResult
{
    QString xlsxPath;
    QString csvPath;
    QString error;   // 空 = 成功
    QString warning; // 非致命提示（如冻结注入失败）

    bool ok() const { return error.isEmpty(); }
};

// 全量导出（设计文档 §3.6 + §11 增补）：
//  xlsx = 原表列序 A–J + 新列（类型/职责/要求/薪资）；状态整行配色（旧表实测值）；
//         跟进链接 writeHyperlink 可点；顶部统计行；冻结前两行（保存后 ZIP 注入 pane，失败降级）；
//  csv  = 同列序，UTF-8 带 BOM（WPS 中文兼容），CRLF。
class Exporter
{
public:
    static ExportResult exportAll(Database &db, const QString &outputDir,
                                  const QDate &today = QDate::currentDate());
};

} // namespace applycompass
