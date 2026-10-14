import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import ApplyCompass

// 两段式表格：已投区 → 待投区（ListView section，设计文档 §3.1）。
ListView {
    id: table
    objectName: "applicationTable"

    clip: true
    model: App.model
    boundsBehavior: Flickable.StopAtBounds

    focus: true
    property int currentId: -1 // 键盘光标行（-1 = 无）
    property int anchorId: -1  // Shift 区间选择锚点（-1 = 无）

    signal rowClicked(int recordId)
    signal emptyAddRequested() // 空态「添加投递」按钮（由 Main 接至 AddDialog）

    // 行是否属于选中区间（单行 = 光标行；Shift 后 = 锚点 ↔ 光标区间）
    function isRowSelected(recordId) {
        if (currentId <= 0)
            return false
        if (recordId === currentId)
            return true
        if (anchorId <= 0)
            return false
        const a = App.model.rowOfRecord(anchorId)
        const c = App.model.rowOfRecord(currentId)
        const r = App.model.rowOfRecord(recordId)
        if (a < 0 || c < 0 || r < 0)
            return false
        return r >= Math.min(a, c) && r <= Math.max(a, c)
    }

    // 选中区间 → { first, last }（可见行序）；无选中 → null（Ctrl+C 用）
    function selectedRange() {
        if (currentId <= 0)
            return null
        const c = App.model.rowOfRecord(currentId)
        if (c < 0)
            return null
        if (anchorId <= 0)
            return { "first": c, "last": c }
        const a = App.model.rowOfRecord(anchorId)
        if (a < 0)
            return { "first": c, "last": c }
        return { "first": Math.min(a, c), "last": Math.max(a, c) }
    }

    function copySelection() {
        const r = selectedRange()
        if (!r)
            return
        App.copyRows(r.first, r.last)
    }

    // Ctrl+滚轮缩放捕获层（真机回归修复 2）：
    // 关键机制——Flickable 能滚动时会先消费滚轮事件，挂在祖先层的 WheelHandler
    // 拿不到（真机症状：只有列表滚到顶/底边缘时缩放才生效）。必须把捕获层放在
    // 列表自身（与 Flickable 同级，handler 先于其自带滚动处理）；非 Ctrl 事件
    // return 放行（blocking:false），由列表继续滚动。
    ZoomWheelHandler { }

    function moveSelection(delta, extend) {
        if (count === 0)
            return
        let idx = currentId > 0 ? App.model.rowOfRecord(currentId) : -1
        if (idx < 0)
            idx = delta > 0 ? 0 : count - 1
        else
            idx = Math.max(0, Math.min(count - 1, idx + delta))
        const id = App.model.recordAtRow(idx).id
        if (!extend || anchorId <= 0)
            anchorId = id
        currentId = id
        positionViewAtIndex(idx, ListView.Contain)
    }

    Keys.onUpPressed: (event) => {
        moveSelection(-1, event.modifiers & Qt.ShiftModifier)
        event.accepted = true
    }
    Keys.onDownPressed: (event) => {
        moveSelection(1, event.modifiers & Qt.ShiftModifier)
        event.accepted = true
    }
    // Ctrl+C：选中行 → TSV 剪贴板（M3）
    Keys.onPressed: (event) => {
        if (event.matches(StandardKey.Copy)) {
            copySelection()
            event.accepted = true
        }
    }
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
            table.anchorId = recordId
            table.rowClicked(recordId)
        }
    }

    // 空态（区分「无数据」与「筛选无结果」）：图标 + 文案 + 行动按钮
    // 注意：Column 位置器忽略带 anchors 的子项 —— 各子项用满宽包装、内部再居中。
    Column {
        anchors.centerIn: parent
        width: Theme.s(320)
        spacing: Theme.gapM
        visible: table.count === 0

        Item {
            width: parent.width
            height: Theme.s(34)

            Image {
                id: emptyIcon
                anchors.centerIn: parent
                source: App.model.filtersActive ? "icons/funnel.svg" : "icons/plus.svg"
                sourceSize.width: Theme.s(28)
                sourceSize.height: Theme.s(28)
            }
            MultiEffect {
                anchors.fill: emptyIcon
                source: emptyIcon
                colorization: 1.0
                colorizationColor: App.model.filtersActive ? Theme.textTertiary : Theme.primary
            }
        }
        Text {
            width: parent.width
            text: App.model.filtersActive
                  ? qsTr("没有匹配的记录")
                  : qsTr("还没有投递记录")
            color: Theme.textTertiary
            font.pixelSize: Theme.fontBody
            horizontalAlignment: Text.AlignHCenter
        }
        Item {
            width: parent.width
            height: Theme.s(32)

            AppButton {
                objectName: "emptyActionButton"
                anchors.centerIn: parent
                variant: App.model.filtersActive ? "ghost" : "primary"
                text: App.model.filtersActive ? qsTr("清除筛选") : qsTr("添加投递")
                icon.source: App.model.filtersActive ? "icons/funnel.svg" : "icons/plus.svg"
                onClicked: {
                    if (App.model.filtersActive)
                        App.model.clearFilters()
                    else
                        table.emptyAddRequested()
                }
            }
        }
    }

    ScrollBar.vertical: AppScrollBar {
        policy: ScrollBar.AsNeeded
    }
}
