import QtQuick
import QtQuick.Controls

import ApplyCompass

// 添加入口表单（设计文档 §3.2）：状态留空 → 入待投区尾；非空 → 走 §5 自动规则。
Dialog {
    id: dialog
    objectName: "addDialog"

    modal: true
    title: qsTr("添加投递")
    anchors.centerIn: parent
    width: Math.min(680, parent ? parent.width - 80 : 680)
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape

    function openForNew() {
        form.reset()
        open()
    }

    RecordForm {
        id: form
        objectName: "addForm"
        width: dialog.availableWidth
    }

    footer: DialogButtonBox {
        Button {
            objectName: "acceptButton"
            text: qsTr("确定")
            enabled: form.valid
            onClicked: {
                if (App.addRecord(form.collect()) >= 0)
                    dialog.close()
            }
        }
        Button {
            objectName: "cancelButton"
            text: qsTr("取消")
            onClicked: dialog.close()
        }
    }
}
