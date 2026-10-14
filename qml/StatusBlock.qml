import QtQuick
import QtQuick.Controls

import ApplyCompass

// 状态彩色块（设计文档 §3.4）。单击 → 下拉 9 项快改（§3.1，popup() 默认在鼠标位置弹出）。
Item {
    id: root
    objectName: "statusBlock"

    property string status: ""
    property bool interactive: true

    signal statusChosen(string status)

    implicitWidth: 74
    implicitHeight: 24

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, 74)
        height: 22
        radius: 4
        color: root.status !== "" ? Theme.statusColor(root.status) : "transparent"
        border.width: 1
        border.color: root.status !== ""
                      ? Qt.darker(Theme.statusColor(root.status), 1.25)
                      : "#cccccc"

        Text {
            anchors.centerIn: parent
            width: parent.width - 8
            text: root.status !== "" ? root.status : "—"
            color: root.status !== "" ? "#1a1a1a" : "#9a9a9a"
            font.pixelSize: 12
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

    Menu {
        id: menu
        objectName: "statusMenu"

        Instantiator {
            model: App.statusOptions
            delegate: MenuItem {
                required property int index
                required property string modelData

                objectName: "statusMenuItem_" + modelData
                text: (modelData === root.status ? "✓  " : "     ") + modelData
                onTriggered: root.statusChosen(modelData)
            }
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
    }
}
