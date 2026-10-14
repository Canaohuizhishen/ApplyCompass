import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角输入框（M4 自绘皮肤）——基于 TextField 模板；结构与 Qt Basic 样式同构，
// 按本项目设计令牌重绘（圆角/边框/焦点态）。API 与 QQC2 TextField 完全一致。
T.TextField {
    id: control

    implicitWidth: implicitBackgroundWidth + leftInset + rightInset
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding,
                             placeholderText.implicitHeight + topPadding + bottomPadding)

    padding: Theme.gapS
    leftPadding: padding + Theme.gapXS

    color: control.enabled ? Theme.textPrimary : Theme.textTertiary
    selectionColor: Theme.primary
    selectedTextColor: "#FFFFFF"
    placeholderTextColor: Theme.textTertiary
    verticalAlignment: TextInput.AlignVCenter

    Text {
        id: placeholderText
        x: control.leftPadding
        y: control.topPadding
        width: control.width - (control.leftPadding + control.rightPadding)
        height: control.height - (control.topPadding + control.bottomPadding)
        text: control.placeholderText
        font: control.font
        color: control.placeholderTextColor
        verticalAlignment: control.verticalAlignment
        visible: !control.length && !control.preeditText
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: Theme.s(160)
        implicitHeight: Theme.s(30)
        radius: Theme.radius
        color: Theme.fieldBg
        border.width: 1
        border.color: control.activeFocus ? Theme.primary : Theme.border
        Behavior on border.color {
            ColorAnimation { duration: Theme.durFast }
        }
    }
}
