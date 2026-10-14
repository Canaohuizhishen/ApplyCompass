pragma Singleton

import QtQuick
import ApplyCompass

// 设计令牌（v2）：颜色 / 字体 / 尺寸 / 间距 的唯一来源。
// 全部尺寸与字号经 zoom（= App.uiZoom，0.7–1.6）缩放 → Ctrl+滚轮整体缩放。
// 9 状态语义色 = 旧表条件格式实测值（2026-10-14，勿动；tst_ui 有锚定回归）。
QtObject {
    // ---------------- 缩放 ----------------
    readonly property real zoom: App.uiZoom
    function s(v) { return Math.round(v * zoom) }                 // 尺寸
    function fs(v) { return Math.max(9, Math.round(v * zoom)) }   // 字号（pixelSize 为 int）

    // ---------------- 颜色：基础 ----------------
    readonly property color bg: "#F5F6F8"          // 窗口底
    readonly property color surface: "#FFFFFF"     // 表面（表格/卡片）
    readonly property color border: "#E4E7EC"
    readonly property color separator: "#F0F1F3"   // 发丝分隔线
    readonly property color textPrimary: "#1D2939"
    readonly property color textSecondary: "#667085"
    readonly property color textTertiary: "#98A2B3"

    // ---------------- 颜色：主色 / 语义 ----------------
    readonly property color primary: "#2563EB"
    readonly property color primaryHover: "#1D4ED8"
    readonly property color primaryPressed: "#1E40AF"
    readonly property color textOnPrimary: "#FFFFFF"   // 注意：勿用 on 前缀命名（QML 会当信号处理器解析）
    readonly property color primarySoft: "#EFF4FF"
    readonly property color danger: "#D92D20"
    readonly property color dangerSoft: "#FEF3F2"
    readonly property color ghostHover: "#F2F4F7"

    // ---------------- 颜色：表格 ----------------
    readonly property color rowHoverColor: "#F0F5FF"
    readonly property color rowAltColor: "#FAFBFC"      // 淡斑马（保留；restyle 视效果取舍）
    readonly property color headBg: "#FFFFFF"
    readonly property color sectionBg: "#F9FAFB"
    readonly property color scrollThumb: "#D0D5DD"
    readonly property color linkColor: "#2563EB"
    readonly property color linkIdleColor: "#D0D5DD"
    readonly property color dotOnColor: "#8FB0F0"
    readonly property color dotOffColor: "#E4E7EC"

    // ---------------- 颜色：待跟进 ----------------
    readonly property color followUpBg: "#FFF7E6"       // 整行浅黄底（§2.3）
    readonly property color followUpAccent: "#F79009"
    readonly property color followUpText: "#B54708"

    // ---------------- 颜色：类型徽标 ----------------
    readonly property color kindInternBg: "#E6F6F1"
    readonly property color kindInternBorder: "#8ED0BE"
    readonly property color kindFormalBg: "#EEF1F8"
    readonly property color kindFormalBorder: "#B8C2DB"
    readonly property color kindText: "#475467"

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
