import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角多行输入（M4 自绘皮肤）——基于 TextArea 模板；API 与 QQC2 TextArea 一致。
T.TextArea {
    id: control

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
