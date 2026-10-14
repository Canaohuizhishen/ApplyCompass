# 投递罗盘 · ApplyCompass

本地单机求职投递管理工具（Qt6 C++/QML + SQLite）。
**设计文档：`docs/设计文档.md`（v1.0）——实现以此为准。**

- **状态**：**M1 完成**（2026-10-14）。骨架 / SQLite 存储 / 两段式表格 / 添加表单 / 详情抽屉 / 状态块快改 / 自动规则（§5）/ 旧表 43 条导入 / 统计条 / 备份轮转。
  M1 验收 = 设计文档 §8 场景 1–6、11（QuickTest 11 用例全绿 + 真机走查通过）。
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
ctest --test-dir build --output-on-failure   # 串行跑；4 个目标
# tst_rule_engine（规则）、tst_database（存储/备份）、tst_importer（旧表导入，需真实文件）、tst_ui（界面场景 1–6）
```

## 数据与备份

- 数据库：`data/applycompass.db`；备份：`data/backups/applycompass_<时间戳>.db`（**每日首启 + 每次退出**各一份，保留最近 14 份）。
- 数据目录覆盖：环境变量 `APPLYCOMPASS_DATA_DIR` 或 `--data-dir <dir>`（测试即用此隔离）。
- 一次性导入旧表（要求库为空，只读打开旧文件）：
  ```bash
  ./build/appApplyCompass --import-legacy "../投递/我的投递记录_宏版.xlsm"
  ```
  跳过【宏测试行】；类型启发：备注含「实习」或源行 40–45 → 实习（可在界面后改）。

## M1 实现记要（决策与坑）

- **状态色值**：自旧表条件格式实测提取，与原表观感一致（见 `qml/Theme.qml`，`tst_ui` 有锚定回归）。
- **QXlsx 日期坑**：其 `Cell::dateTime()` 差一天（序列号 46305 → 10-09，正确 10-10），导入器自算（1899-12-30 纪元），测试锚定。
- **QQC2 样式锁定 Fusion**：本机 KDE Breeze 样式与 Qt 6.11 不兼容（TextArea 告警），Fusion 行为一致且输出干净；M3 深浅色打磨时重估。
- **排序语义**（§5 落点）：`sort_index` 全局递增——填状态取 max+1（入已投区尾）；清空**保留原值**（回待投区原位）；日期在清空时保留。
- **快捷入口**：`Ctrl+Q` 退出；其余快捷键（`n`/`/`/`1-9`/`Ctrl+E`/`Esc`）按计划在 M2。
- **探针纪律**：GUI 探针必须显式 `QT_QPA_PLATFORM=offscreen`（或 `DISPLAY=:97` + 剥 `WAYLAND_DISPLAY` 强制 xcb），防止弹到真实桌面。
- **M1 未做（按计划）**：搜索/筛选/待跟进行高亮与点击筛选（场景 8）、导出 xlsx+csv（场景 10）、全量快捷键、窗口布局记忆、表格内文本选中复制（与单击开详情手势冲突，留 M3）。

## 相关记忆

`applycompass-design`（设计定稿）、`job-application-tracker`（数据沿革）、`tracker-macro-v2`（旧表宏技术内幕）。
