import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 主窗口：工具条（+ 添加 / 统计条 / 缩放%）+ 两段式表格（表头+列表，横向滚动容器）+ 对话框/抽屉。
ApplicationWindow {
    id: window
    objectName: "mainWindow"

    width: 1320
    height: 820
    minimumWidth: 980
    minimumHeight: 560
    visible: true
    color: Theme.bg
    title: qsTr("投递罗盘 · ApplyCompass")

    // 窗口布局记忆（M3，§10）：恢复大小/最大化/位置（含屏幕越界校验，防丢窗）。
    // Wayland 下窗口位置由合成器掌控（setPosition 不生效）——位置尽力而为，尺寸/最大化可靠。
    Component.onCompleted: {
        const s = App.loadWindowState()
        if (s.width === undefined)
            return
        if (s.maximized === true) {
            visibility = Window.Maximized
        } else {
            if (s.x >= 0 && s.y >= 0) {
                x = s.x
                y = s.y
            }
            width = s.width
            height = s.height
        }
    }
    function persistWindowState() {
        if (window.visibility === Window.Maximized || window.visibility === Window.FullScreen)
            App.saveWindowState(-1, -1, window.width, window.height, true)
        else
            App.saveWindowState(window.x, window.y, window.width, window.height, false)
    }
    // 变更去抖（600ms）+ 关闭时落盘
    Timer {
        id: geometryDebounce
        interval: 600
        onTriggered: window.persistWindowState()
    }
    onXChanged: geometryDebounce.restart()
    onYChanged: geometryDebounce.restart()
    onWidthChanged: geometryDebounce.restart()
    onHeightChanged: geometryDebounce.restart()
    onClosing: window.persistWindowState()

    // Ctrl+Q 退出（优雅退出会触发退出备份，§3.8）
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }

    // Ctrl+滚轮缩放由 ZoomWheelHandler 统一处理（经典滚轮 angleDelta / 触摸板 pixelDelta）

    // 状态多选切换（筛选条用）
    function toggleStatusFilter(status) {
        let list = App.model.statusFilter.slice()
        const i = list.indexOf(status)
        if (i >= 0)
            list.splice(i, 1)
        else
            list.push(status)
        App.model.statusFilter = list
    }

    // 文本输入聚焦时快捷键让位（§11 增补）：以 cursorPosition 识别文本编辑控件
    readonly property bool typingInField: {
        const it = window.activeFocusItem
        return !!(it && it.cursorPosition !== undefined)
    }
    readonly property bool popupOpen: addDialog.opened || drawer.opened

    // 1–9：为选中行快速改状态（§3.7）
    function quickStatus(digit) {
        const id = table.currentId
        if (id <= 0)
            return
        App.quickChangeStatus(id, App.statusOptions[digit - 1])
    }

    // ---- 快捷键（§3.7）----
    Shortcut {
        sequence: "n"
        enabled: !window.typingInField && !window.popupOpen
        onActivated: addDialog.openForNew()
    }
    Shortcut {
        sequence: "/"
        enabled: !window.typingInField && !window.popupOpen
        onActivated: {
            searchField.forceActiveFocus()
            searchField.selectAll()
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: !window.popupOpen
        onActivated: {
            if (searchField.text !== "") {
                searchField.text = ""
            } else if (App.model.filtersActive) {
                App.model.clearFilters()
            } else {
                table.currentId = -1
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+E"
        enabled: !window.typingInField && !window.popupOpen
        onActivated: App.exportAll()
    }

    component DigitShortcut: Shortcut {
        property int digit: 0
        sequence: "" + digit
        enabled: !window.typingInField && !window.popupOpen
        onActivated: window.quickStatus(digit)
    }

    DigitShortcut { digit: 1 }
    DigitShortcut { digit: 2 }
    DigitShortcut { digit: 3 }
    DigitShortcut { digit: 4 }
    DigitShortcut { digit: 5 }
    DigitShortcut { digit: 6 }
    DigitShortcut { digit: 7 }
    DigitShortcut { digit: 8 }
    DigitShortcut { digit: 9 }

    // 数据库错误横幅（打开失败时提示，不挡操作）
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 30
        color: Theme.dangerSoft
        visible: App.errorMessage !== ""
        z: 100
        Text {
            anchors.centerIn: parent
            text: App.errorMessage
            color: Theme.danger
            font.pixelSize: Theme.fontBody
        }
    }

    header: ToolBar {
        id: toolBar
        implicitHeight: Theme.toolbarHeight

        background: Rectangle {
            color: Theme.surface
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }
        }

        ZoomWheelHandler { }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            AppButton {
                objectName: "addButton"
                variant: "primary"
                text: qsTr("添加")
                icon.source: "icons/plus.svg"
                onClicked: addDialog.openForNew()
            }

            AppButton {
                objectName: "exportButton"
                variant: "ghost"
                text: qsTr("导出")
                icon.source: "icons/export.svg"
                onClicked: App.exportAll()
            }

            Item { Layout.fillWidth: true }

            StatBar { }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Ctrl+滚轮捕获层分布（每条事件路径上有且只有一个，否则会双跳）：
        // 工具栏→ ToolBar 内｜筛选条→ filterBar 内｜表头→ tableHeader 内｜表格→ ApplicationTable 内

        // 筛选条（§3.5）：搜索 / 状态多选 / 类型 / 地区 / 待跟进 / 清除
        Rectangle {
            id: filterBar
            objectName: "filterBar"
            Layout.fillWidth: true
            implicitHeight: Theme.filterBarHeight
            color: Theme.surface

            ZoomWheelHandler { }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }

            function syncControls() {
                kindCombo.currentIndex = App.model.kindFilter === "实习" ? 1
                                       : App.model.kindFilter === "正式" ? 2 : 0
                const regions = regionCombo.regionModel
                const ri = App.model.regionFilter === "" ? 0 : regions.indexOf(App.model.regionFilter)
                regionCombo.currentIndex = ri >= 0 ? ri : 0
                followUpToggle.checked = App.model.followUpOnly
                if (searchField.text !== App.model.searchText)
                    searchField.text = App.model.searchText
            }

            Connections {
                target: App.model
                function onFiltersChanged() { filterBar.syncControls() }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.gapM
                anchors.rightMargin: Theme.gapM
                spacing: Theme.gapS

                TextField {
                    id: searchField
                    objectName: "searchField"
                    Layout.preferredWidth: Theme.s(260)
                    placeholderText: qsTr("搜索 公司/岗位/地区/备注")
                    onTextChanged: App.model.searchText = text
                }

                Button {
                    id: statusFilterButton
                    objectName: "statusFilterButton"
                    text: App.model.statusFilter.length === 0
                          ? qsTr("状态")
                          : qsTr("状态 · %1").arg(App.model.statusFilter.length)
                    onClicked: statusFilterMenu.popup()

                    Menu {
                        id: statusFilterMenu
                        Instantiator {
                            model: App.statusOptions
                            delegate: MenuItem {
                                required property string modelData
                                text: modelData
                                checkable: true
                                checked: App.model.statusFilter.indexOf(modelData) !== -1
                                onTriggered: window.toggleStatusFilter(modelData)
                            }
                            onObjectAdded: (index, object) => statusFilterMenu.insertItem(index, object)
                            onObjectRemoved: (index, object) => statusFilterMenu.removeItem(object)
                        }
                    }
                }

                ComboBox {
                    id: kindCombo
                    objectName: "kindFilterCombo"
                    model: [qsTr("类型：全部"), qsTr("实习"), qsTr("正式")]
                    onActivated: App.model.kindFilter = currentIndex === 1 ? "实习"
                                : currentIndex === 2 ? "正式" : ""
                }

                ComboBox {
                    id: regionCombo
                    objectName: "regionFilterCombo"
                    property var regionModel: [qsTr("地区：全部")].concat(App.model.regionOptions)
                    model: regionModel
                    onActivated: App.model.regionFilter = currentIndex === 0 ? "" : regionModel[currentIndex]
                }

                Button {
                    id: followUpToggle
                    objectName: "followUpToggle"
                    checkable: true
                    text: qsTr("待跟进")
                    icon.source: "icons/warn.svg"
                    icon.color: Theme.followUpText
                    onToggled: App.model.followUpOnly = checked
                }

                Button {
                    objectName: "clearFiltersButton"
                    text: qsTr("清除筛选")
                    visible: App.model.filtersActive
                    onClicked: App.model.clearFilters()
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: qsTr("共 %1 条").arg(App.model.visibleCount)
                    color: Theme.textTertiary
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        // 表格区域：横向滚动容器（缩放 >100% 时表头与行同步横滚；竖向拖拽交给列表）
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface

            Flickable {
                id: tableScroll
                objectName: "tableScroll"

                anchors.fill: parent
                contentWidth: Math.max(width, Theme.tableContentWidth)
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    width: tableScroll.contentWidth
                    height: tableScroll.height

                    // 表头（与行共用 Theme.colWidths）
                    Rectangle {
                        id: tableHeader
                        objectName: "tableHeader"
                        width: parent.width
                        height: Theme.tableHeaderHeight
                        color: Theme.headBg

                        ZoomWheelHandler { }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.colMargin
                            anchors.rightMargin: Theme.colMargin
                            Repeater {
                                model: Theme.colKeys
                                Text {
                                    required property int index
                                    required property string modelData

                                    width: Theme.colWidths[modelData]
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: Theme.colTitles[index]
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSmall
                                    font.bold: true
                                }
                            }
                        }
                    }

                    ApplicationTable {
                        id: table
                        width: parent.width
                        height: parent.height - tableHeader.height
                        onRowClicked: (recordId) => drawer.openFor(recordId)
                        onEmptyAddRequested: addDialog.openForNew()
                    }
                }

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }

    // 导出/操作结果提示（点击打开导出目录；6 秒自动消散）
    Rectangle {
        id: toast
        objectName: "toast"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.gapL
        width: toastText.implicitWidth + Theme.gapL * 2
        height: Theme.s(36)
        radius: Theme.radiusCard
        // 悬浮提示：两主题都维持“深底浅字”浮层观感；暗色下加边界与背景区分
        color: Theme.dark ? "#232935" : "#101828"
        border.width: Theme.dark ? 1 : 0
        border.color: Theme.dark ? "#3A4150" : "transparent"
        visible: opacity > 0
        opacity: App.lastExportMessage !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durSlow } }
        z: 200

        Text {
            id: toastText
            anchors.centerIn: parent
            text: App.lastExportMessage
            color: "#FFFFFF"
            font.pixelSize: Theme.fontSmall
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                App.openExportFolder()
                App.clearExportMessage()
            }
        }
        Timer {
            interval: 6000
            running: toast.visible
            onTriggered: App.clearExportMessage()
        }
    }

    AddDialog { id: addDialog }

    DetailsDrawer { id: drawer }
}
