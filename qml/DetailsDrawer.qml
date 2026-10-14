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
    width: Math.min(640, parent ? parent.width * 0.58 : 640)
    height: parent ? parent.height : 720
    interactive: true
    closePolicy: Popup.CloseOnEscape

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
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("投递详情")
                font.bold: true
                font.pixelSize: 15
            }
            Item { Layout.fillWidth: true }
            Button {
                objectName: "closeDrawerButton"
                text: "\u2715"
                flat: true
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
            Label { text: qsTr("跟进链接") }
            Label {
                Layout.fillWidth: true
                text: form.linkText
                elide: Text.ElideMiddle
                color: Theme.linkColor
            }
            Button {
                objectName: "openLinkButton"
                text: qsTr("打开")
                onClicked: App.openLink(form.linkText)
            }
        }

        Label {
            text: qsTr("状态时间线")
            font.bold: true
        }

        Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: 112

            ListView {
                id: timelineList
                objectName: "timelineList"
                anchors.fill: parent
                clip: true
                model: timelineModel

                delegate: Row {
                    width: timelineList.width
                    height: 20
                    spacing: 10
                    Text {
                        width: 130
                        text: model.at
                        color: "#666666"
                        font.pixelSize: 12
                    }
                    Text {
                        text: model.from + " → " + model.to
                        font.pixelSize: 12
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: timelineModel.count === 0
                text: qsTr("（暂无记录）")
                color: "#999999"
                font.pixelSize: 12
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Button {
                objectName: "deleteButton"
                text: qsTr("删除该行")
                onClicked: confirmDialog.open()
            }
            Item { Layout.fillWidth: true }
            Button {
                objectName: "saveButton"
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
        width: 420
        modal: true
        title: qsTr("删除确认")

        Label {
            text: qsTr("确定删除「%1」？此操作不可撤销。").arg(form.companyText)
        }

        footer: DialogButtonBox {
            Button {
                objectName: "confirmDeleteButton"
                text: qsTr("删除")
                onClicked: {
                    App.removeRecord(drawer.recordId)
                    confirmDialog.close()
                    drawer.close()
                }
            }
            Button {
                text: qsTr("取消")
                onClicked: confirmDialog.close()
            }
        }
    }
}
