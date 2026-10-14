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
    closePolicy: Popup.CloseOnEscape
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
        anchors.fill: parent
        anchors.margins: Theme.gapL
        spacing: Theme.gapM

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

        ZoomWheelHandler { }

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
                Layout.fillWidth: true
                text: form.linkText
                elide: Text.ElideMiddle
                color: Theme.linkColor
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

        Item { Layout.fillHeight: true }

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
            text: qsTr("确定删除「%1」？此操作不可撤销。").arg(form.companyText)
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
