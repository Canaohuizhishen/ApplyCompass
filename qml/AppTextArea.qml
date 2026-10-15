import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角多行输入（M4 自绘皮肤）——基于 TextArea 模板；API 与 QQC2 TextArea 一致。
T.TextArea {
    id: control

    // 字号令牌：模板自身即文本编辑器（QQuickTextArea : QQuickTextEdit），不设则回落
    // 应用默认字体（固定像素，不随 zoom）——M7 修复。占位文本经 control.font 联动。
    font.pixelSize: Theme.fontBody

    implicitWidth: implicitBackgroundWidth + leftInset + rightInset
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    padding: Theme.gapS
    leftPadding: padding

    color: control.enabled ? Theme.textPrimary : Theme.textTertiary
    selectionColor: Theme.primary
    selectedTextColor: "#FFFFFF"
    placeholderTextColor: Theme.textTertiary
    selectByMouse: true

    Text {
        id: placeholderText
        x: control.leftPadding
        y: control.topPadding
        width: control.width - (control.leftPadding + control.rightPadding)
        height: control.height - (control.topPadding + control.bottomPadding)
        text: control.placeholderText
        font: control.font
        color: control.placeholderTextColor
        visible: !control.length && !control.preeditText
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: Theme.s(160)
        implicitHeight: Theme.s(70)
        radius: Theme.radius
        color: Theme.fieldBg
        border.width: 1
        border.color: control.activeFocus ? Theme.primary : Theme.border
        Behavior on border.color {
            ColorAnimation { duration: Theme.durFast }
        }
    }
}
