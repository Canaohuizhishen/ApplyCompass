# 投递罗盘 · ApplyCompass

本地单机求职投递管理工具（Qt6 C++/QML + SQLite）。
**设计文档：`docs/设计文档.md`（v1.0）——实现以此为准。**

- **状态**：**M2 完成**（2026-10-14）。M1 = 骨架 / SQLite / 两段式表格 / 表单 / 详情抽屉 / 状态快改 / 自动规则 / 43 条导入 / 统计条 / 备份轮转；M2 = 搜索与筛选 / 待跟进提醒 / 导出 xlsx+csv / 快捷键全量 / **Ctrl+滚轮缩放** / **视觉刷新**（详见设计文档 §11 增补）。
  M1 验收 = §8 场景 1–6、11；M2 验收 = §8 场景 7–10（均通过：QuickTest + openpyxl 交叉验证 + 真机走查）。
- **内核**：方便记录投递信息——点「+ 添加」表单录入、单击行看详情、状态块单击快改；日期 / 归位 / 变色自动完成。
- **技术栈**：Qt 6.11 C++/QML、SQLite（QtSql）、CMake/Ninja；旧表导入 QXlsx（`pacman extra/qxlsx`）。
- **目录**：`src/core/`（记录/规则/存储/模型/导入）｜`qml/`（界面）｜`tests/`（QTest + QuickTest）｜`data/`（运行期库与备份，不入库）｜`docs/`。

## 构建与运行

```bash
cmake -B build -G Ninja -S .
cmake --build build --parallel 4        # 本机纪律：显式限并行（严禁裸 --parallel，曾致全机 OOM）
./build/appApplyCompass                  # Ctrl+Q 退出（优雅退出会触发退出备份）
```

## 测试

```bash
ctest --test-dir build --output-on-failure   # 串行跑；6 个目标
# tst_rule_engine（规则）、tst_database（存储/备份）、tst_importer（旧表导入，需真实文件）、
# tst_model（待跟进边界/筛选双口径）、tst_export（xlsx 读回/CSV BOM/冻结注入）、tst_ui（界面全场景）
```

## 使用要点（M2）

- **Ctrl+滚轮缩放**（Excel 式，70%–160%，10% 步进）：主窗口任意处生效，顶栏显示百分比（点击恢复 100%），设置持久化。
- **搜索**（`/` 聚焦）：公司 / 岗位 / 地区 / 备注 中文模糊匹配；**筛选**：状态（多选）/ 类型 / 地区 / 「⚠ 待跟进」可叠加，工具栏「清除筛选」或 `Esc` 清除。
- **待跟进**：初筛且状态更新 >14 天 → 整行浅黄 + 左缘琥珀条 + 顶栏 chip 计数（点击一键筛选）。
- **快捷键**：`n` 添加 ｜ `/` 搜索 ｜ `↑` `↓` 选行 ｜ `Enter` 详情 ｜ `1`–`9` 改选中行状态 ｜ `Ctrl+E` 导出 ｜ `Esc` 关抽屉/清搜索/清筛选 ｜ `Ctrl+Q` 退出。文本输入聚焦时自动让位。
- **导出**：`Ctrl+E` 或「导出」→ `投递/导出/投递罗盘_YYYY-MM-DD.xlsx`（原列序 + 新列 / 状态整行配色 / 链接可点 / 顶部统计 / 冻结前两行）+ 同名 `.csv`（UTF-8 BOM）。导出后点提示条可打开目录。

## 数据与备份

- 数据库：`data/applycompass.db`；备份：`data/backups/applycompass_<时间戳>.db`（**每日首启 + 每次退出**各一份，保留最近 14 份）。
- 数据目录覆盖：环境变量 `APPLYCOMPASS_DATA_DIR` 或 `--data-dir <dir>`（测试即用此隔离）。
- 一次性导入旧表（要求库为空，只读打开旧文件）：
  ```bash
  ./build/appApplyCompass --import-legacy "../投递/我的投递记录_宏版.xlsm"
  ```
  跳过【宏测试行】；类型启发：备注含「实习」或源行 40–45 → 实习（可在界面后改）。

## M1 实现记要（决策与坑）

- **状态色值**：自旧表条件格式实测提取，与原表观感一致（见 `qml/Theme.qml`，`tst_ui` 有锚定回归）；C++ 导出侧同表在 `src/core/exporter.cpp`。
- **QXlsx 日期坑**：其 `Cell::dateTime()` 差一天（序列号 46305 → 10-09，正确 10-10），导入器自算（1899-12-30 纪元），测试锚定。
- **QQC2 样式锁定 Fusion**：本机 KDE Breeze 样式与 Qt 6.11 不兼容（TextArea 告警），Fusion 行为一致且输出干净；M3 深浅色打磨时重估。
- **字体**：显式设定 `Noto Sans CJK SC`（本机 fontconfig 默认回落 Droid Sans Fallback，观感差的主因）。
- **排序语义**（§5 落点）：`sort_index` 全局递增——填状态取 max+1（入已投区尾）；清空**保留原值**（回待投区原位）；日期在清空时保留。
- **探针纪律**：GUI 探针必须显式 `QT_QPA_PLATFORM=offscreen`（或 `DISPLAY=:97` + 剥 `WAYLAND_DISPLAY` 强制 xcb），防止弹到真实桌面。
- **M2 补记**：导出冻结 = 保存后 ZIP 注入 `<pane>`（QXlsx 无 API；注意注入点是**单数** `<sheetView>` 元素、且可能自闭合需展开，测试有回归锚点）；`xdotool type` 的后续参数会被并入输入文本（脚本演示时勿在 type 后链式追加命令）。
- **M1 未做（按计划）**：动效/深浅色/图标、窗口布局记忆、表格内文本选中复制（与单击开详情手势冲突，留 M3）。

## 相关记忆

`applycompass-design`（设计定稿）、`job-application-tracker`（数据沿革）、`tracker-macro-v2`（旧表宏技术内幕）。
