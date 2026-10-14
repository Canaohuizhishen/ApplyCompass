import QtQuick
import QtQuick.Controls

import ApplyCompass

// 表格数据行（自绘委托，设计文档 §6）。单击行 = 唤出详情（§2.2）。
// 状态块 / 链接图标在行之上，各自消费点击。
Item {
    id: root
    // 逐行唯一（rowDelegate_<id>）：测试与调试可直接定位
    objectName: "rowDelegate_" + model.id

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.rowHeight

    // 行标识（测试与后续键盘导航用）
    readonly property int recordId: model.id
    readonly property string companyText: model.company

    signal rowClicked(int recordId)

    Rectangle {
        anchors.fill: parent
        color: rowMouse.containsMouse
               ? Theme.rowHoverColor
               : (index % 2 === 0 ? "#ffffff" : Theme.rowAltColor)
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.rowClicked(model.id)
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Text {
            width: Theme.colWidths.company
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.company
            elide: Text.ElideRight
            font.pixelSize: 13
        }
        Text {
            width: Theme.colWidths.position
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.position
            elide: Text.ElideRight
            font.pixelSize: 13
        }

        // 类型徽标
        Item {
            width: Theme.colWidths.kind
            height: parent.height
            Rectangle {
                anchors.centerIn: parent
                width: kindText.implicitWidth + 12
                height: 18
                radius: 3
                color: model.kind === "实习" ? "#e4f2ee" : "#edeff7"
                border.width: 1
                border.color: model.kind === "实习" ? "#8fbfb0" : "#a8b0cc"
                Text {
                    id: kindText
                    anchors.centerIn: parent
                    text: model.kind
                    font.pixelSize: 11
                    color: "#3c3c3c"
                }
            }
        }

        Text {
            width: Theme.colWidths.region
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.region
            elide: Text.ElideRight
            font.pixelSize: 13
        }
        Text {
            width: Theme.colWidths.applyDate
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.applyDateText
            font.pixelSize: 13
        }
        Text {
            width: Theme.colWidths.channel
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.channel
            elide: Text.ElideRight
            font.pixelSize: 13
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
            font.pixelSize: 13
        }
        Text {
            width: Theme.colWidths.resume
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: model.resumeVersion
            elide: Text.ElideRight
            font.pixelSize: 13
        }

        // 跟进链接（有链接才亮；点击用系统浏览器打开）
        Item {
            width: Theme.colWidths.link
            height: parent.height
            Text {
                anchors.centerIn: parent
                text: "\u2197"
                font.pixelSize: 16
                color: model.hasLink ? Theme.linkColor : "#d5d5d5"
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
            spacing: 5
            Rectangle {
                y: (parent.height - 8) / 2
                width: 8; height: 8; radius: 4
                color: model.hasDuties ? Theme.dotOnColor : Theme.dotOffColor
            }
            Rectangle {
                y: (parent.height - 8) / 2
                width: 8; height: 8; radius: 4
                color: model.hasRequirements ? Theme.dotOnColor : Theme.dotOffColor
            }
            Rectangle {
                y: (parent.height - 8) / 2
                width: 8; height: 8; radius: 4
                color: model.hasNotes ? Theme.dotOnColor : Theme.dotOffColor
            }
        }
    }
}
