pragma Singleton

import QtQuick
import ApplyCompass

// 设计令牌（v2）：颜色 / 字体 / 尺寸 / 间距 的唯一来源。
// 全部尺寸与字号经 zoom（= App.uiZoom，0.7–1.6）缩放 → Ctrl+滚轮整体缩放。
// 9 状态语义色 = 旧表条件格式实测值（2026-10-14，勿动；tst_ui 有锚定回归）。
QtObject {
    // ---------------- 主题模式（M3） ----------------
    // 跟随系统深浅色（App.darkMode，来源见 AppController）；
    // 9 个状态语义色在两模式下保持一致（旧表实测值，勿动；tst_ui 有锚定回归）。
    readonly property bool dark: App.darkMode

    // ---------------- 缩放 ----------------
    readonly property real zoom: App.uiZoom
    function s(v) { return Math.round(v * zoom) }                 // 尺寸
    function fs(v) { return Math.max(9, Math.round(v * zoom)) }   // 字号（pixelSize 为 int）

    // ---------------- 动效时长（M3） ----------------
    readonly property int durFast: 120   // 悬停/颜色过渡
    readonly property int dur: 150       // 标准（对话框淡入）
    readonly property int durSlow: 180   // toast 淡入淡出等大件

    // ---------------- 颜色：基础 ----------------
    readonly property color bg: dark ? "#11151C" : "#F5F6F8"          // 窗口底
    readonly property color surface: dark ? "#171B23" : "#FFFFFF"      // 表面（表格/卡片）
    readonly property color border: dark ? "#2A303B" : "#E4E7EC"
    readonly property color separator: dark ? "#20252F" : "#F0F1F3"    // 发丝分隔线
    readonly property color textPrimary: dark ? "#E7EAF0" : "#1D2939"
    readonly property color textSecondary: dark ? "#A3ABB9" : "#667085"
    readonly property color textTertiary: dark ? "#6F7A8C" : "#98A2B3"

    // ---------------- 颜色：主色 / 语义 ----------------
    readonly property color primary: dark ? "#3B82F6" : "#2563EB"
    readonly property color primaryHover: dark ? "#5B97F8" : "#1D4ED8"
    readonly property color primaryPressed: dark ? "#2F6FE0" : "#1E40AF"
    readonly property color textOnPrimary: "#FFFFFF"   // 注意：勿用 on 前缀命名（QML 会当信号处理器解析）
    readonly property color primarySoft: dark ? "#1D2A44" : "#EFF4FF"
    readonly property color danger: dark ? "#F97066" : "#D92D20"
    readonly property color dangerSoft: dark ? "#3B2220" : "#FEF3F2"
    readonly property color ghostHover: dark ? "#232935" : "#F2F4F7"

    // ---------------- 颜色：表格 ----------------
    readonly property color rowHoverOverlay: dark ? "#14FFFFFF" : "#142563EB" // 行悬停/选中叠加层（主色 ≈8%）
    readonly property color headBg: dark ? "#171B23" : "#FFFFFF"
    readonly property color sectionBg: dark ? "#1B202A" : "#F9FAFB"
    readonly property color scrollThumb: dark ? "#3A4150" : "#D0D5DD"
    readonly property color linkColor: dark ? "#6D9BF8" : "#2563EB"
    readonly property color linkIdleColor: dark ? "#3A4150" : "#D0D5DD"
    readonly property color dotOnColor: dark ? "#5B82D6" : "#8FB0F0"
    readonly property color dotOffColor: dark ? "#2E3542" : "#E4E7EC"

    // ---------------- 颜色：控件（M4 圆角皮肤） ----------------
    readonly property color fieldBg: dark ? "#161A22" : "#FFFFFF"      // 输入/下拉底色
    readonly property color softBg: dark ? "#232935" : "#F2F4F7"       // 柔和按钮常态
    readonly property color softBgHover: dark ? "#2E3542" : "#E4E7EC"  // 柔和按钮悬停/按下

    // ---------------- 颜色：待跟进 ----------------
    readonly property color followUpBg: dark ? "#3A2E12" : "#FFF7E6"       // 整行浅黄底（§2.3）
    readonly property color followUpAccent: dark ? "#FDB022" : "#F79009"
    readonly property color followUpText: dark ? "#FDB022" : "#B54708"

    // ---------------- 颜色：类型徽标 ----------------
    readonly property color kindInternBg: dark ? "#1C332D" : "#E6F6F1"
    readonly property color kindInternBorder: dark ? "#2F6A58" : "#8ED0BE"
    readonly property color kindFormalBg: dark ? "#232B3B" : "#EEF1F8"
    readonly property color kindFormalBorder: dark ? "#3A4763" : "#B8C2DB"
    readonly property color kindText: dark ? "#C3CAD6" : "#475467"

    // ---------------- 状态语义色（旧表实测，勿动） ----------------
    readonly property var statusColors: ({
        "初筛": "#E7E6E6",
        "笔试": "#FFE699",
        "面试": "#BDD7EE",
        "Offer": "#C6EFCE",
        "简历挂": "#FFC7CE",
        "笔试挂": "#FFC7CE",
        "面试挂": "#FFC7CE",
        "挂": "#FFC7CE",
        "放弃": "#D0CECE"
    })

    function statusColor(status) {
        return statusColors[status] !== undefined ? statusColors[status] : "transparent"
    }

    // 浅色状态胶囊上的文字色（9 状态色均为浅底；不随深浅主题变化）
    readonly property color statusPillText: "#1a1a1a"

    // ---------------- 行状态配色（M3：整行变色） ----------------
    // 状态非空 → 整行底色 = 该状态色。浅色 = 旧表纯色（与导出的「状态整行配色」一致）；
    // 深色 = 状态色以 ~16% 混入暗表面（保持色相语义、避免浅色大块刺眼）。
    // 注意：statusColors 的 9 个值本身保持不变（旧表实测，测试锚定）。
    function rowStatusColor(status) {
        const hex = statusColors[status]
        if (hex === undefined)
            return "transparent"
        if (!dark)
            return hex
        const r = parseInt(hex.substring(1, 3), 16) / 255.0
        const g = parseInt(hex.substring(3, 5), 16) / 255.0
        const b = parseInt(hex.substring(5, 7), 16) / 255.0
        return Qt.tint(surface, Qt.rgba(r, g, b, 0.16))
    }

    // ---------------- 尺寸（基准 × zoom） ----------------
    readonly property int radius: s(6)
    readonly property int radiusCard: s(10)
    readonly property int rowHeight: s(32)
    readonly property int sectionHeaderHeight: s(28)
    readonly property int tableHeaderHeight: s(30)
    readonly property int toolbarHeight: s(54)
    readonly property int filterBarHeight: s(44)
    readonly property int colMargin: s(8)

    readonly property var colKeys: [
        "company", "position", "kind", "region", "applyDate", "channel",
        "status", "statusUpdated", "resume", "link", "dots"
    ]
    readonly property var colTitles: [
        "公司", "岗位", "类型", "地区", "投递日期", "渠道",
        "状态", "状态更新", "简历版本", "链接", "内容点"
    ]
    readonly property var colWidths: {
        const z = zoom
        const w = function(v) { return Math.round(v * z) }
        return {
            company: w(176),
            position: w(256),
            kind: w(64),
            region: w(132),
            applyDate: w(96),
            channel: w(64),
            status: w(92),
            statusUpdated: w(96),
            resume: w(156),
            link: w(40),
            dots: w(56)
        }
    }
    // 表格内容总宽（含左右边距）：横向滚动容器与行宽共用
    readonly property int tableContentWidth: {
        let total = 2 * colMargin
        for (let i = 0; i < colKeys.length; ++i)
            total += colWidths[colKeys[i]]
        return total
    }

    // ---------------- 字体（基准 × zoom） ----------------
    readonly property int fontTitle: fs(16)
    readonly property int fontBody: fs(13)
    readonly property int fontSmall: fs(12)
    readonly property int fontTiny: fs(11)
    readonly property int fontBadge: fs(11)

    // ---------------- 间距（基准 × zoom） ----------------
    readonly property int gapXS: s(4)
    readonly property int gapS: s(8)
    readonly property int gapM: s(12)
    readonly property int gapL: s(16)
}
