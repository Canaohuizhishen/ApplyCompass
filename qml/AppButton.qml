import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import ApplyCompass

// 统一按钮（variant：primary 实主色 / soft 柔和浅底（可勾选）/ ghost 幽灵描边 / danger 危险文字）
// 尺寸与字体随 Theme 令牌缩放。
// 图标（可选）：单色 SVG + MultiEffect 染色——icon.color 未指定时跟随文本色。
Button {
    id: control

    property string variant: "ghost"

    implicitHeight: Theme.s(32)
    font.pixelSize: Theme.fontBody
    leftPadding: Theme.gapM
    rightPadding: Theme.gapM
    topPadding: Theme.gapXS
    bottomPadding: Theme.gapXS

    readonly property color _contentColor: {
        if (!control.enabled)
            return Theme.textTertiary
        if (control.variant === "primary")
            return Theme.textOnPrimary
        if (control.variant === "danger")
            return Theme.danger
        if (control.variant === "soft" && control.checked)
            return Theme.primary
        return Theme.textPrimary
    }
    readonly property color _iconTint: control.icon.color.a > 0 ? control.icon.color : control._contentColor

    // 注意：contentItem 用 RowLayout——Row 位置器会忽略带 anchors 的子项（尺寸归零），
    // 曾致按钮收缩成图标宽度、文字溢出按钮外。
    contentItem: RowLayout {
        spacing: control.icon.source.toString() !== "" && control.text !== "" ? Theme.gapXS : 0

        Item {
            visible: control.icon.source.toString() !== ""
            Layout.preferredWidth: Theme.s(15)
            Layout.preferredHeight: Theme.s(15)
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: iconImage
                anchors.fill: parent
                source: control.icon.source
                sourceSize.width: Theme.s(15)
                sourceSize.height: Theme.s(15)
            }
            MultiEffect {
                anchors.fill: iconImage
                source: iconImage
                colorization: 1.0
                colorizationColor: control._iconTint
            }
        }
        Text {
            id: labelText
            Layout.alignment: Qt.AlignVCenter
            text: control.text
            font: control.font
            color: control._contentColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: Theme.radius
        border.width: control.variant === "ghost" ? 1 : 0
        border.color: Theme.border
        color: {
            if (!control.enabled)
                return control.variant === "primary"
                       ? (Theme.dark ? "#33507F" : "#A9C2F5") : "transparent"
            if (control.variant === "soft") {
                if (control.pressed || control.hovered)
                    return Theme.softBgHover
                if (control.checked)
                    return Theme.primarySoft
                return Theme.softBg
            }
            if (control.pressed)
                return control.variant === "primary" ? Theme.primaryPressed : Theme.ghostHover
            if (control.hovered)
                return control.variant === "primary" ? Theme.primaryHover
                     : control.variant === "danger" ? Theme.dangerSoft
                     : Theme.ghostHover
            return control.variant === "primary" ? Theme.primary : "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: Theme.durFast }
        }
    }
}
