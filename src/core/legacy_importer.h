#pragma once

#include <QString>

#include "core/database.h"

namespace applycompass {

struct ImportSummary
{
    int imported = 0;  // 成功导入条数（应为 43）
    int skipped = 0;   // 跳过行数（含【宏测试行】）
    QString error;     // 空 = 成功
};

// 一次性导入旧表 xlsm（只读打开，绝不清写；原始目录已退役，路径由调用方提供）。
// 映射见设计文档 §4.3：A..J 列对应字段；行 3 起、跳过【宏测试行】；
// 类型启发：备注含"实习"或源行 40–45 → 实习，其余正式；职责/要求/薪资留空。
class LegacyImporter
{
public:
    static ImportSummary importFromXlsm(const QString &xlsmPath, Database &db);

    // Excel 1900 日期系统序列号 → QDate（epoch 1899-12-30）。
    // 注意：不得使用 QXlsx Cell::dateTime()——实测其转换差一天
    //（46305 得 2026-10-09，正确为 2026-10-10），故自行换算。
    static QDate excelSerialToDate(double serial);
};

} // namespace applycompass
