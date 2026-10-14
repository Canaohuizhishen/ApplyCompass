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

    focus: true
    property int currentId: -1 // 键盘选中行（-1 = 无）

    signal rowClicked(int recordId)

    function moveSelection(delta) {
        if (count === 0)
            return
        let idx = currentId > 0 ? App.model.rowOfRecord(currentId) : -1
        if (idx < 0)
            idx = delta > 0 ? 0 : count - 1
        else
            idx = Math.max(0, Math.min(count - 1, idx + delta))
        currentId = App.model.recordAtRow(idx).id
        positionViewAtIndex(idx, ListView.Contain)
    }

    Keys.onUpPressed: (event) => { moveSelection(-1); event.accepted = true }
    Keys.onDownPressed: (event) => { moveSelection(1); event.accepted = true }
    Keys.onReturnPressed: (event) => {
        if (currentId > 0) {
            table.rowClicked(currentId)
            event.accepted = true
        }
    }
    Keys.onEnterPressed: (event) => {
        if (currentId > 0) {
            table.rowClicked(currentId)
            event.accepted = true
        }
    }

    section.property: "section"
    section.criteria: ViewSection.FullString
    section.delegate: Rectangle {
        width: table.width
        height: Theme.sectionHeaderHeight
        color: Theme.sectionBg

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.gapM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gapS

            Rectangle { // 小色条
                width: Theme.s(3)
                height: Theme.s(12)
                radius: width / 2
                color: Number(section) === 0 ? Theme.primary : Theme.textTertiary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Number(section) === 0
                      ? qsTr("已投区（%1）").arg(App.model.visibleAppliedCount)
                      : qsTr("待投区（%1）").arg(App.model.visiblePendingCount)
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: Theme.textSecondary
            }
        }
    }

    delegate: RowDelegate {
        onRowClicked: (recordId) => {
            table.currentId = recordId
            table.rowClicked(recordId)
        }
    }

    // 空态（区分「无数据」与「筛选无结果」）
    Text {
        anchors.centerIn: parent
        visible: table.count === 0
        text: App.model.filtersActive
              ? qsTr("没有匹配的记录——试试清除筛选")
              : qsTr("还没有投递记录——点「+ 添加」开始")
        color: Theme.textTertiary
        font.pixelSize: Theme.fontBody
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
}
