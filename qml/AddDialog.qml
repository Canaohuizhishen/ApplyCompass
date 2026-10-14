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
    width: Math.min(Theme.s(680), parent ? parent.width - Theme.s(80) : Theme.s(680))
    padding: Theme.gapL
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape

    // 透明自定义 header：Fusion 默认 header 的不透明底色块会盖住圆角（M4 方角元凶）
    header: Label {
        text: dialog.title
        leftPadding: Theme.gapL
        rightPadding: Theme.gapL
        topPadding: Theme.gapM
        bottomPadding: 0
        font.pixelSize: Theme.fontTitle
        font.bold: true
        color: Theme.textPrimary
    }

    // 轻量淡入淡出（M3 动效）
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusCard
        border.width: 1
        border.color: Theme.border
    }

    function openForNew() {
        form.reset()
        open()
    }

    ZoomWheelHandler { }

    RecordForm {
        id: form
        objectName: "addForm"
        width: dialog.availableWidth
    }

    footer: DialogButtonBox {
        spacing: Theme.gapS

        AppButton {
            objectName: "acceptButton"
            variant: "primary"
            text: qsTr("确定")
            enabled: form.valid
            onClicked: {
                if (App.addRecord(form.collect()) >= 0)
                    dialog.close()
            }
        }
        AppButton {
            objectName: "cancelButton"
            variant: "ghost"
            text: qsTr("取消")
            onClicked: dialog.close()
        }
    }
}
