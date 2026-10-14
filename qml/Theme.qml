pragma Singleton

import QtQuick

// 主题与配色唯一来源。
// 状态配色 = 自旧表（宏版.xlsm）条件格式实测提取（2026-10-14），与原表观感一致（设计文档 §3.4）。
QtObject {
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

    // 表格列宽（表头与行委托共用唯一来源；键与 delegate 中使用的角色一一对应）
    readonly property var colKeys: [
        "company", "position", "kind", "region", "applyDate", "channel",
        "status", "statusUpdated", "resume", "link", "dots"
    ]
    readonly property var colTitles: [
        "公司", "岗位", "类型", "地区", "投递日期", "渠道",
        "状态", "状态更新", "简历版本", "链接", "内容点"
    ]
    readonly property var colWidths: ({
        company: 170,
        position: 250,
        kind: 60,
        region: 130,
        applyDate: 92,
        channel: 64,
        status: 84,
        statusUpdated: 92,
        resume: 152,
        link: 40,
        dots: 56
    })

    readonly property int rowHeight: 30
    readonly property int sectionHeaderHeight: 26
    readonly property color rowHoverColor: "#eef5ff"
    readonly property color rowAltColor: "#fafbfc"
    readonly property color linkColor: "#2b6cb0"
    readonly property color dotOnColor: "#5b8fd9"
    readonly property color dotOffColor: "#e2e2e2"
}
