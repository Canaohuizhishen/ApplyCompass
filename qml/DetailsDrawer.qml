import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 详情抽屉（设计文档 §3.3）：右侧滑出；全字段编辑（含状态、Offer 薪资显隐）、
// 职责/要求/备注全文、跟进链接（系统浏览器打开）、状态时间线（只读）、删除（二次确认）。
Drawer {
    id: drawer
    objectName: "detailsDrawer"

    edge: Qt.RightEdge
    width: Math.min(Theme.s(640), parent ? parent.width * 0.58 : Theme.s(640))
    height: parent ? parent.height : 720
    interactive: true
    // M5：点击抽屉外部（modal 遮罩区）即关闭——QQC2 原生 CloseOnPressOutside 由 Overlay
    // 遮罩捕获（自加 MouseArea 会被 modal 遮罩挡住收不到事件）；Esc/拖动关闭保持。
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0

    background: Rectangle {
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
    }

    property int recordId: -1

    function openFor(id) {
        recordId = id
        form.loadFrom(App.recordDetails(id))
        refreshTimeline()
        open()
    }

    function refreshTimeline() {
        timelineModel.clear()
        const events = App.timeline(recordId)
        for (let i = 0; i < events.length; ++i) {
            timelineModel.append({
                "at": events[i].at,
                "from": events[i].from !== "" ? events[i].from : qsTr("（空）"),
                "to": events[i].to !== "" ? events[i].to : qsTr("（空）")
            })
        }
    }

    ListModel { id: timelineModel }

    ColumnLayout {
        id: contentRoot
        anchors.fill: parent
        anchors.margins: Theme.gapL
        spacing: Theme.gapM

        // M6.2：兜底点击——标题/按钮间隙等未被控件消费的空白点击冒泡到此 → 收回字段焦点
        // （被控件消费的点击在子级即被接受、不会冒泡到这里；字段聚焦后可由此退出）
        TapHandler {
            onTapped: contentRoot.forceActiveFocus()
        }

        // 显式固定调色板：本机环境（KDE 平台主题）下抽屉子树的 QQC2 控件会解析到
        // 系统（Breeze）调色板而非应用调色板（对话框/主窗口不受影响），导致浅色主题
        // 下表单控件仍是暗色。这里在内容根上直接钉住与 Theme 一致的角色值，子项继承。
        palette.base: Theme.dark ? "#161A22" : "#FFFFFF"
        palette.alternateBase: Theme.dark ? "#1A1E27" : "#FAFBFC"
        palette.window: Theme.dark ? "#1E222A" : "#FFFFFF"
        palette.windowText: Theme.textPrimary
        palette.text: Theme.textPrimary
        palette.placeholderText: Theme.textTertiary
        palette.button: Theme.dark ? "#2A2F3A" : "#F2F4F7"
        palette.buttonText: Theme.textPrimary
        palette.highlight: Theme.primary
        palette.highlightedText: "#FFFFFF"
        palette.light: Theme.dark ? "#4A5262" : "#FFFFFF"
        palette.midlight: Theme.dark ? "#323946" : "#E4E7EC"
        palette.mid: Theme.dark ? "#3A4150" : "#D0D5DD"
        palette.dark: Theme.dark ? "#20252F" : "#98A2B3"
        palette.shadow: Theme.dark ? "#0D1015" : "#D0D5DD"

        // M7：捕获层分区挂载（标题行/表单滚区/底栏各一个）——同一事件路径上有且只有
        // 一个；根级挂会被表单滚区（ScrollView→Flickable）消费抢先，嵌套多层会双跳。
        // 表单滚区内的捕获层见下方 formScroll（Flickable 自身）。

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("投递详情")
                font.bold: true
                font.pixelSize: Theme.fontTitle
                color: Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
            AppButton {
                objectName: "closeDrawerButton"
                variant: "ghost"
                icon.source: "icons/close.svg"
                icon.color: Theme.textPrimary
                onClicked: drawer.close()
            }

            ZoomWheelHandler { }
        }

        // 表单+链接+时间线：滚动区（窗口小/缩放>100% 时内部滚动，底部操作行始终可见）。
        // M7：ScrollView → 自管 Flickable——ScrollView 包装会无条件消费纵向滚轮，缩放捕获
        // 层必须挂在滚动器自身才能先于消费拿到 Ctrl+滚轮（实测结论；同 ApplicationTable /
        // M6.1 FieldScroll 模式）；非 Ctrl 事件原样放行，由 Flickable 照常滚动。
        Flickable {
            id: formScroll
            objectName: "drawerFormScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: formColumn.implicitHeight
            // 与旧 ScrollView 语义对齐：自然高度=内容高（不影响本处 fillHeight，
            // 但保持隐式高度可读/可复用的一致性）
            implicitHeight: contentHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

            ZoomWheelHandler { }

            ColumnLayout {
                id: formColumn
                width: formScroll.width
                spacing: Theme.gapM

                // M6.2：表单与时间线之间的空白/标签点击 → 收回字段焦点
                TapHandler {
                    onTapped: contentRoot.forceActiveFocus()
                }

                RecordForm {
                    id: form
                    objectName: "detailForm"
                    Layout.fillWidth: true
                }

                // 跟进链接（可点用系统浏览器打开）
                RowLayout {
                    Layout.fillWidth: true
                    visible: form.linkText !== ""
                    Label {
                        text: qsTr("跟进链接")
                        font.pixelSize: Theme.fontSmall
                        color: Theme.textSecondary
                    }
                    Label {
                        objectName: "linkValueLabel"
                        Layout.fillWidth: true
                        text: form.linkText
                        elide: Text.ElideMiddle
                        color: Theme.linkColor
                        font.pixelSize: Theme.fontBody // M7：补字号令牌（原为应用默认字体，不随 zoom）
                    }
                    AppButton {
                        objectName: "openLinkButton"
                        variant: "ghost"
                        text: qsTr("打开")
                        onClicked: App.openLink(form.linkText)
                    }
                }

                Label {
                    text: qsTr("状态时间线")
                    font.bold: true
                    font.pixelSize: Theme.fontBody
                    color: Theme.textPrimary
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.s(112)
                    color: Theme.sectionBg
                    radius: Theme.radius
                    border.width: 1
                    border.color: Theme.border

                    ListView {
                        id: timelineList
                        objectName: "timelineList"
                        anchors.fill: parent
                        anchors.margins: Theme.gapS
                        clip: true
                        model: timelineModel
                        // M6.1：条目装得下时禁用事件接收 → 滚轮穿透给页面；可滚时保持域内滚动
                        // （只读列表，禁用无副作用；enabled 门控穿透为实测有效机制）
                        enabled: contentHeight > height + 1

                        delegate: Row {
                            width: timelineList.width
                            height: Theme.s(20)
                            spacing: Theme.gapM
                            Text {
                                width: Theme.s(130)
                                text: model.at
                                color: Theme.textTertiary
                                font.pixelSize: Theme.fontSmall
                            }
                            Text {
                                text: model.from + " → " + model.to
                                font.pixelSize: Theme.fontSmall
                                color: Theme.textSecondary
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: timelineModel.count === 0
                        text: qsTr("（暂无记录）")
                        color: Theme.textTertiary
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            AppButton {
                objectName: "deleteButton"
                variant: "danger"
                text: qsTr("删除该行")
                icon.source: "icons/trash.svg"
                onClicked: confirmDialog.open()
            }
            Item { Layout.fillWidth: true }
            AppButton {
                objectName: "saveButton"
                variant: "primary"
                text: qsTr("保存")
                enabled: form.valid
                onClicked: {
                    if (App.updateRecord(drawer.recordId, form.collect())) {
                        // 回读：自动日期、引擎副作用后的最终状态
                        form.loadFrom(App.recordDetails(drawer.recordId))
                        drawer.refreshTimeline()
                    }
                }
            }

            ZoomWheelHandler { }
        }
    }

    Dialog {
        id: confirmDialog
        objectName: "confirmDeleteDialog"
        anchors.centerIn: parent
        width: Theme.s(420)
        modal: true
        title: qsTr("删除确认")
        padding: Theme.gapL

        // 透明自定义 header（同 AddDialog：Fusion 默认 header 盖住圆角）
        header: Label {
            text: confirmDialog.title
            leftPadding: Theme.gapL
            rightPadding: Theme.gapL
            topPadding: Theme.gapM
            bottomPadding: 0
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.textPrimary
        }

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
            border.width: 1
            border.color: Theme.border
        }

        Label {
            objectName: "confirmDeleteText"
            text: qsTr("确定删除「%1」？此操作不可撤销。").arg(form.companyText)
            font.pixelSize: Theme.fontBody // M7：补字号令牌（原为应用默认字体，不随 zoom）
        }

        footer: DialogButtonBox {
            spacing: Theme.gapS
            AppButton {
                objectName: "confirmDeleteButton"
                variant: "danger"
                text: qsTr("删除")
                onClicked: {
                    App.removeRecord(drawer.recordId)
                    confirmDialog.close()
                    drawer.close()
                }
            }
            AppButton {
                variant: "ghost"
                text: qsTr("取消")
                onClicked: confirmDialog.close()
            }
        }
    }
}
