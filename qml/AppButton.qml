import QtQuick
import QtQuick.Controls

import ApplyCompass

// 统一按钮（variant：primary 实主色 / ghost 幽灵描边 / danger 危险文字）
// 尺寸与字体随 Theme 令牌缩放。
Button {
    id: control

    property string variant: "ghost"

    implicitHeight: Theme.s(32)
    font.pixelSize: Theme.fontBody
    leftPadding: Theme.gapM
    rightPadding: Theme.gapM
    topPadding: Theme.gapXS
    bottomPadding: Theme.gapXS

    contentItem: Text {
        text: control.text
        font: control.font
        color: {
            if (!control.enabled)
                return Theme.textTertiary
            if (control.variant === "primary")
                return Theme.textOnPrimary
            if (control.variant === "danger")
                return Theme.danger
            return Theme.textPrimary
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radius
        border.width: control.variant === "ghost" ? 1 : 0
        border.color: Theme.border
        color: {
            if (!control.enabled)
                return control.variant === "primary" ? "#A9C2F5" : "transparent"
            if (control.pressed)
                return control.variant === "primary" ? Theme.primaryPressed : Theme.ghostHover
            if (control.hovered)
                return control.variant === "primary" ? Theme.primaryHover
                     : control.variant === "danger" ? Theme.dangerSoft
                     : Theme.ghostHover
            return control.variant === "primary" ? Theme.primary : "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }
}
