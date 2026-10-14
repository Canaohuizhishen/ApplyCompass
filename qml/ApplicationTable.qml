import QtQuick
import QtQuick.Controls

import ApplyCompass

// 两段式表格：已投区 → 待投区（ListView section，设计文档 §3.1）。
ListView {
    id: table
    objectName: "applicationTable"

    clip: true
    model: App.model
    boundsBehavior: Flickable.StopAtBounds

    signal rowClicked(int recordId)

    section.property: "section"
    section.criteria: ViewSection.FullString
    section.delegate: Rectangle {
        width: table.width
        height: Theme.sectionHeaderHeight
        color: "#eef1f5"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Number(section) === 0
                  ? qsTr("已投区（%1）").arg(App.model.totalApplied)
                  : qsTr("待投区（%1）").arg(table.count - App.model.totalApplied)
            font.pixelSize: 12
            font.bold: true
            color: "#55606e"
        }
    }

    delegate: RowDelegate {
        onRowClicked: (recordId) => table.rowClicked(recordId)
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
}
