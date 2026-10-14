import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 添加入口表单（设计文档 §3.2）：状态留空 → 入待投区尾；非空 → 走 §5 自动规则。
// M6：改为自管布局（标题 + 滚动表单 + 底部按钮同一 ColumnLayout）——窗口小/缩放 >100%
// 时表单内部滚动、按钮始终可见（原「Dialog header/footer + 表单直放」在钳制高度下
// 会内容重叠/截断，列探针实测；M4 的 Fusion 透明 header 补丁随之不再需要）。
Dialog {
    id: dialog
    objectName: "addDialog"

    modal: true
    title: qsTr("添加投递")
    anchors.centerIn: parent
    width: Math.min(Theme.s(680), parent ? parent.width - Theme.s(80) : Theme.s(680))
    // 高度自适应内容；窗口放不下时留出上下边距（Theme.s(24)×2），
    // 避免「居中 + 超高钳制」把对话框顶部（含标题）顶出窗外（探针实测修正）
    height: Math.min(implicitHeight, (parent ? parent.height : 720) - Theme.s(48))
    padding: 0
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape

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

    ColumnLayout {
        id: contentRoot
        anchors.fill: parent
        spacing: Theme.gapM

        // M6.2：标题/按钮间隙等未被控件消费的空白点击 → 收回字段焦点
        TapHandler {
            onTapped: contentRoot.forceActiveFocus()
        }

        Label {
            text: dialog.title
            Layout.leftMargin: Theme.gapL
            Layout.rightMargin: Theme.gapL
            Layout.topMargin: Theme.gapM
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.textPrimary
        }

        ScrollView {
            id: formScroll
            objectName: "addFormScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.gapL
            Layout.rightMargin: Theme.gapL
            contentWidth: availableWidth
            ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

            RecordForm {
                id: form
                objectName: "addForm"
                width: formScroll.availableWidth
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.gapL
            Layout.rightMargin: Theme.gapL
            Layout.bottomMargin: Theme.gapL
            spacing: Theme.gapS

            Item { Layout.fillWidth: true }
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
}
