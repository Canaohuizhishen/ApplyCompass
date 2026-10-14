#pragma once

#include <QString>

namespace applycompass {

// 数据目录解析（设计文档 §3.8：数据 = data/applycompass.db）。
// 顺序：APPLYCOMPASS_DATA_DIR 环境变量 > 编译期默认（仓库 data/）。
// 测试通过环境变量指向临时目录。
QString resolveDataDir();

// 导出目录解析（设计文档 §3.6：默认 投递/导出/）。
// 顺序：APPLYCOMPASS_EXPORT_DIR 环境变量 > 编译期默认（仓库 ../投递/导出）> <dataDir>/导出 兜底。
QString resolveExportDir();

} // namespace applycompass
