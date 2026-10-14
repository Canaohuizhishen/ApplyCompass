# 投递罗盘 · ApplyCompass

本地单机求职投递管理工具（Qt6 C++/QML + SQLite）。
**设计文档：`docs/设计文档.md`（v1.0）——实现以此为准。**

- **状态**：**M6 完成**（2026-10-14）。M1 = 骨架 / SQLite / 两段式表格 / 表单 / 详情抽屉 / 状态快改 / 自动规则 / 43 条导入 / 统计条 / 备份轮转；M2 = 搜索与筛选 / 待跟进提醒 / 导出 xlsx+csv / 快捷键全量 / Ctrl+滚轮缩放 / 视觉刷新；M3 = 整行状态配色 / 深浅色跟随系统 / SVG 图标集与空态 / 轻量动效 / 窗口布局记忆 / Ctrl+C 复制选中行 TSV；M4 = **控件全面圆角化（根治对话框方角）** / 设置面板（主题三态/缩放复位/数据维护/关于）；M5 = **主题持久化时序修复** / 设置页布局重构（分段控件） / 抽屉与设置**点外部关闭** / 顶栏 chip 去图标；M6 = **导出补旧表同款 #BFBFBF 细边框** / 抽屉与添加对话框**滚动兜底** / 复制反馈 toast + 打磨批（详见设计文档 §11–§15）。
  M1 验收 = §8 场景 1–6、11；M2 验收 = §8 场景 7–10；M3/M4 验收 = §8 十一条全回归 + 圆角剖面实证（均通过）。
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
ctest --test-dir build --output-on-failure   # 串行跑；7 个目标
# tst_rule_engine（规则）、tst_database（存储/备份）、tst_importer（旧表导入，需真实文件）、
# tst_model（待跟进边界/筛选双口径/TSV 复制）、tst_export（xlsx 读回/CSV BOM/冻结注入）、
# tst_controller（启动逻辑：主题偏好持久化/跨重启往返）、tst_ui（界面全场景：24 用例）
# 直跑 tst_ui 须给 -input：tst_ui -input tests/qml（否则 QuickTest 扫描 cwd 会误拾其他仓库的 tst_*.qml）
```

## 使用要点（M4）

- **Ctrl+滚轮缩放**（Excel 式，70%–160%，10% 步进）：主窗口任意处生效，顶栏显示百分比（点击恢复 100%），设置持久化。
- **深浅色**：跟随系统（KDE 切换即时生效）；`APPLYCOMPASS_FORCE_DARK=1` / `APPLYCOMPASS_FORCE_LIGHT=1` 强制覆盖（截图/测试用）。
- **整行状态配色**：状态非空即整行染状态色——浅色主题 = 旧表条件格式纯色（与导出一致）；深色主题 = 状态色 16% 混入暗表面；待跟进浅黄+琥珀条优先；悬停 = 主色叠加层、键盘选中 = 主色描边。
- **搜索**（`/` 聚焦）：公司 / 岗位 / 地区 / 备注 中文模糊匹配；**筛选**：状态（多选）/ 类型 / 地区 / 「待跟进」可叠加，工具栏「清除筛选」或 `Esc` 清除。
- **待跟进**：初筛且状态更新 >14 天 → 整行浅黄 + 左缘琥珀条 + 顶栏 chip 计数（点击一键筛选）。
- **快捷键**：`n` 添加 ｜ `/` 搜索 ｜ `↑` `↓` 选行（`Shift+↑↓` 区间）｜ `Ctrl+C` 复制选中行（TSV，可直接粘进 WPS/Excel）｜ `Enter` 详情 ｜ `1`–`9` 改选中行状态 ｜ `Ctrl+E` 导出 ｜ `Esc` 关抽屉/清搜索/清筛选 ｜ `Ctrl+Q` 退出。文本输入聚焦时自动让位。
- **窗口布局记忆**：尺寸 / 位置 / 最大化自动保存与恢复（含屏幕越界校验）；Wayland 下位置由合成器掌控（尽力而为），尺寸/最大化可靠。
- **设置**（工具栏齿轮）：主题三态（跟随系统 / 浅色 / 深色，持久化；`APPLYCOMPASS_FORCE_*` 环境变量仍最优先）、缩放复位（100%）、数据维护（打开数据目录 / 打开备份目录 / 立即备份）、关于；**Esc 或点对话框外任意处关闭**。
- **点外部关闭**（M5）：详情抽屉（点左半区）与设置面板均支持点外部关闭——修完即时生效，无需找关闭按钮。
- **控件圆角**（M4）：按钮 / 输入框 / 下拉框 / 菜单 / 滚动条 / 对话框统一圆角（控件 6px、浮层 10px 令牌；Shift 前的 Fusion 方形观感已移除）。
- **导出**：`Ctrl+E` 或「导出」→ `投递/导出/投递罗盘_YYYY-MM-DD.xlsx`（原列序 + 新列 / 状态整行配色 / **全表 #BFBFBF 细边框（旧表同款）** / 链接可点 / 顶部统计 / 冻结前两行）+ 同名 `.csv`（UTF-8 BOM）。导出后点提示条可打开目录。

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
- **QQC2 样式锁定 Fusion**：本机 KDE Breeze 样式与 Qt 6.11 不兼容（TextArea 告警），Fusion 行为一致且输出干净；M3 以 QPalette 暗色底座实现深浅色（见下）。
- **字体**：显式设定 `Noto Sans CJK SC`（本机 fontconfig 默认回落 Droid Sans Fallback，观感差的主因）。
- **排序语义**（§5 落点）：`sort_index` 全局递增——填状态取 max+1（入已投区尾）；清空**保留原值**（回待投区原位）；日期在清空时保留。
- **探针纪律**：GUI 探针必须显式 `QT_QPA_PLATFORM=offscreen`（或 `DISPLAY=:97` + 剥 `WAYLAND_DISPLAY` 强制 xcb），防止弹到真实桌面。
- **M2 补记**：导出冻结 = 保存后 ZIP 注入 `<pane>`（QXlsx 无 API；注意注入点是**单数** `<sheetView>` 元素、且可能自闭合需展开，测试有回归锚点）；`xdotool type` 的后续参数会被并入输入文本（脚本演示时勿在 type 后链式追加命令）。
- **M3 补记**（实现时踩过的坑，勿重蹈）：
  - **行位置器中带 anchors 的子项不计入尺寸**：`Row`/`Column` 位置器会忽略带 anchors 子项的隐式尺寸（曾致 AppButton 收缩成图标宽、文字溢出；`RowLayout` 或满宽包装才是正解）。
  - **Drawer 子树的调色板**：本机（KDE 平台主题，Breeze Dark 会话）下 QQC2 控件解析到系统调色板而非应用 `setPalette`——抽屉表单在浅色主题下呈现暗色。修复 = `DetailsDrawer.qml` 内容根上以显式 `palette.<role>` 角色值钉住（与 `AppController` 的明/暗双 QPalette 色值对齐）。
  - **MultiEffect 染色**：自绘单色 SVG 图标统一走 `QtQuick.Effects.MultiEffect`（`colorization: 1.0`）跟随主题色；QQC2 按钮用内置 `icon.source/icon.color`。
  - **直跑 tst_ui**：必须给 `-input tests/qml`（否则 QuickTest 扫描 cwd，会把同级其他仓库的 `tst_*.qml` 误拾进来）。
- **M4 补记**：
  - **Fusion 对话框“方角”元凶**：Fusion 样式 Dialog 自带默认 header（标题栏），其背景是一块不透明 `palette.window` 色矩形（仅 2px 圆角），盖住我们的圆角对话框背景 → 全部对话框改用**透明自定义 header**（保留标题文字）。
  - **控件圆角化路径**：Fusion 的 Button/ComboBox/TextField/Menu/ScrollBar 本体是方的 → 按 Qt 官方《Customizing Qt Quick Controls》所述，基于 `QtQuick.Templates` 自绘 `AppComboBox/AppTextField/AppTextArea/AppMenu(+AppMenuItem)/AppScrollBar`（结构参照 Basic 样式、令牌重绘）；**objectName 与对外 API 不变**，23 个 UI 用例零改动。规范：控件 6px / 浮层 10px（与 Fluent 的 4/8 分级同构）。
  - **主题优先级链**（勿颠倒）：`APPLYCOMPASS_FORCE_*` 环境 ＞ `setDarkModeOverride`（测试钩子）＞ `settings.theme` 用户偏好 ＞ 系统 `colorScheme`。— 调试“点了设置不变色”时先查 FORCE env！
- **M5 补记**：
  - **主题偏好“重启失效”根因**：`initialize()` 里 `initDarkMode()`（含首次重算）跑在偏好读库之前，读入后未再重算 → 启动被系统色覆盖。修复=读入后补一次 `recomputeDarkMode()`；`tst_controller` 锚定（含跨重启往返，修复前必挂）。
  - **点外部关闭用 QQC2 原生 `Popup.CloseOnPressOutside`**：抽屉与设置面板通用；**自加 MouseArea 捕获层会被 modal 遮罩（Overlay dim）吃掉点击收不到事件——已实测排除，勿回退**。
  - 设置页：分段控件（连体三段，激活段主色实底）+ 标签列对齐 + 发丝分隔 + 「完成」主按钮；objectName 全保留。
- **M6.1 补记（滚轮委派）**：多行文本域与时间线在"未聚焦或内容装得下"时，纵向滚轮穿透给页面（`Flickable.flickableDirection` 方向门控——Qt 不消费与方向不符的滚轮；不可滚列表用 `enabled` 门控）；聚焦且可滚才域内滚动。未聚焦域上 Ctrl+滚轮现在可达缩放链（原先失灵）。
- **M6.2 补记（点空白失焦）**：详情抽屉/添加对话框内点击标签、标题、空白等非交互区域 → 字段失焦（`TapHandler` 兜底：被控件消费的点击不会冒泡到它，控件零误伤）；聚焦字段后想恢复页面滚动，点一下空白即可。已知例外：时间线区域与窗边边距带不触发。
- **M6 补记**：
  - **合成点击的“行几何中心”陷阱（测试侧）**：缩放 >100% 时表格内容宽于窗口，`mouseClick(row)` 按几何中心合成点击会落在窗口可视区之外 → 无命中（rowClicked 信号不发出、childAt 为 null）。测试须改点行内窗口必然可见的左侧点；曾因此把既有行为误诊为抽屉竞态。
  - **QQuickPopup 退场期间 `visible` 仍为 true**（`opened` 已 false）：判断“是否关闭”别只看 `opened`；Qt 对退场中重开有专门处理（`setVisible` 守卫注释），无需自加 workaround——曾据此误加守卫后回滚。
  - 导出边框与抽屉/对话框滚动兜底的细节见设计文档 §15。
- **M1 遗留项收口**：动效 / 深浅色 / 图标、窗口布局记忆、表格内文本选中复制——已于 M3 完成（复制采用 `Ctrl+C` 选中行 TSV 方案，拖拽划选仍因与「单击开详情」手势冲突而不做）。
## 相关记忆

`applycompass-design`（设计定稿）、`job-application-tracker`（数据沿革）、`tracker-macro-v2`（旧表宏技术内幕）。
