import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import ApplyCompass

// 表格数据行（自绘委托，设计文档 §6）。单击行 = 唤出详情（§2.2）。
// 状态块 / 链接图标在行之上，各自消费点击。
//
// 行底色（M3 整行变色）：待跟进（§2.3）＞ 状态色 ＞ 待投白。
//   状态非空 → 整行 = 状态色（浅色=旧表纯色，与导出一致；深色=低透明度合成色，见 Theme.rowStatusColor）。
//   悬停/键盘选中不再整行替换色（否则丢掉状态色、与待跟进打架）：
//   悬停 = 主色低透明度叠加层；键盘选中 = 主色内描边 + 同叠加层。
Item {
    id: root
    // 逐行唯一（rowDelegate_<id>）：测试与调试可直接定位
    objectName: "rowDelegate_" + model.id

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.rowHeight

    // 行标识（测试与键盘导航用）
    readonly property int recordId: model.id
    readonly property string companyText: model.company
    // 键盘选中（含 Shift 区间，M3 复制）：由视图统一判定
    readonly property bool selected: ListView.view ? ListView.view.isRowSelected(model.id) : false

    // 行底色（优先级见文件头注释）
    readonly property color rowBaseColor: model.followUpDue ? Theme.followUpBg
                                        : model.status !== "" ? Theme.rowStatusColor(model.status)
                                        : Theme.surface

    signal rowClicked(int recordId)

    Rectangle {
        id: rowBackground
        objectName: "rowBackground"
        anchors.fill: parent
        color: root.rowBaseColor
    }
    // 待跟进左缘琥珀条
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.s(3)
        color: Theme.followUpAccent
        visible: model.followUpDue
    }
    // 悬停 / 键盘选中叠加层（纯色行上不做整行替换色）
    Rectangle {
        objectName: "rowHoverOverlay"
        anchors.fill: parent
        color: Theme.rowHoverOverlay
        opacity: rowMouse.containsMouse || root.selected ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
    // 键盘选中：主色内描边（在任意底色上都清晰）
    Rectangle {
        objectName: "rowSelectedBorder"
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Theme.primary
        visible: root.selected
    }
    // 发丝分隔线
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.separator
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.rowClicked(model.id)
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.colMargin
        anchors.rightMargin: Theme.colMargin

        Text {
            width: Theme.colWidths.company
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.company
            elide: Text.ElideRight
            font.pixelSize: Theme.fontBody
            color: Theme.textPrimary
        }
        Text {
            width: Theme.colWidths.position
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.position
            elide: Text.ElideRight
            font.pixelSize: Theme.fontBody
            color: Theme.textPrimary
        }

        // 类型徽标（胶囊）
        Item {
            width: Theme.colWidths.kind
            height: parent.height
            Rectangle {
                anchors.centerIn: parent
                width: kindText.implicitWidth + Theme.gapM
                height: Theme.s(18)
                radius: height / 2
                color: model.kind === "实习" ? Theme.kindInternBg : Theme.kindFormalBg
                border.width: 1
                border.color: model.kind === "实习" ? Theme.kindInternBorder : Theme.kindFormalBorder
                Text {
                    id: kindText
                    anchors.centerIn: parent
                    text: model.kind
                    font.pixelSize: Theme.fontBadge
                    color: Theme.kindText
                }
            }
        }

        Text {
            width: Theme.colWidths.region
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.region
            elide: Text.ElideRight
            font.pixelSize: Theme.fontBody
            color: Theme.textSecondary
        }
        Text {
            width: Theme.colWidths.applyDate
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.applyDateText
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
        }
        Text {
            width: Theme.colWidths.channel
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.channel
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
        }

        // 状态块（单击快改）
        Item {
            width: Theme.colWidths.status
            height: parent.height
            StatusBlock {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                status: model.status
                onStatusChosen: (status) => App.quickChangeStatus(model.id, status)
            }
        }

        Text {
            width: Theme.colWidths.statusUpdated
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.statusUpdatedText
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
        }
        Text {
            width: Theme.colWidths.resume
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.resumeVersion
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
        }

        // 跟进链接（有链接才亮；点击用系统浏览器打开）
        Item {
            width: Theme.colWidths.link
            height: parent.height
            Image {
                id: linkIcon
                objectName: "linkIcon"
                anchors.centerIn: parent
                source: "icons/link.svg"
                sourceSize.width: Theme.s(14)
                sourceSize.height: Theme.s(14)
            }
            MultiEffect {
                anchors.fill: linkIcon
                source: linkIcon
                colorization: 1.0
                colorizationColor: model.hasLink ? Theme.linkColor : Theme.linkIdleColor
            }
            MouseArea {
                anchors.fill: parent
                enabled: model.hasLink
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: App.openLink(model.link)
            }
        }

        // 内容点：职责 / 要求 / 备注
        Row {
            width: Theme.colWidths.dots
            height: parent.height
            spacing: Theme.s(5)
            Rectangle {
                y: (parent.height - height) / 2
                width: Theme.s(8); height: Theme.s(8); radius: height / 2
                color: model.hasDuties ? Theme.dotOnColor : Theme.dotOffColor
            }
            Rectangle {
                y: (parent.height - height) / 2
                width: Theme.s(8); height: Theme.s(8); radius: height / 2
                color: model.hasRequirements ? Theme.dotOnColor : Theme.dotOffColor
            }
            Rectangle {
                y: (parent.height - height) / 2
                width: Theme.s(8); height: Theme.s(8); radius: height / 2
                color: model.hasNotes ? Theme.dotOnColor : Theme.dotOffColor
            }
        }
    }
}
