import QtQuick
import QtQuick.Controls

import ApplyCompass

// 状态胶囊（设计文档 §3.4）。单击 → 下拉 9 项快改（§3.1，popup() 默认在鼠标位置弹出）。
Item {
    id: root
    objectName: "statusBlock"

    property string status: ""
    property bool interactive: true

    signal statusChosen(string status)

    implicitWidth: Theme.s(74)
    implicitHeight: Theme.s(24)

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: Math.min(parent.width, Theme.s(76))
        height: Theme.s(20)
        radius: height / 2
        color: root.status !== "" ? Theme.statusColor(root.status) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        border.width: 1
        border.color: root.status !== ""
                      ? Qt.darker(Theme.statusColor(root.status), 1.2)
                      : Theme.border

        Text {
            anchors.centerIn: parent
            width: parent.width - Theme.gapS
            text: root.status !== "" ? root.status : "—"
            color: root.status !== "" ? Theme.statusPillText : Theme.textTertiary
            font.pixelSize: Theme.fontBadge
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.popup()
    }

    AppMenu {
        id: menu
        objectName: "statusMenu"

        Instantiator {
            model: App.statusOptions
            delegate: AppMenuItem {
                required property int index
                required property string modelData

                objectName: "statusMenuItem_" + modelData
                text: modelData
                checkable: true
                checked: modelData === root.status
                onTriggered: root.statusChosen(modelData)
            }
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
    }
}
