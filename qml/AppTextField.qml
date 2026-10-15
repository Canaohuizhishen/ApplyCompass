import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角输入框（M4 自绘皮肤）——基于 TextField 模板；结构与 Qt Basic 样式同构，
// 按本项目设计令牌重绘（圆角/边框/焦点态）。API 与 QQC2 TextField 完全一致。
T.TextField {
    id: control

    // 字号令牌：模板自身即文本编辑器（QQuickTextField : QQuickTextInput），font 为 override
    // 属性直接驱动渲染；不设则回落应用默认字体（固定像素，不随 zoom）——曾致详情页输入
    // 文本不缩放（M7 修复）。占位文本经 `font: control.font` 绑定自动联动。
    font.pixelSize: Theme.fontBody

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
