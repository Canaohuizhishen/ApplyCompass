import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角菜单条目（M4 自绘皮肤）——基于 MenuItem 模板；勾选态用主色 ✓ 标记。
T.MenuItem {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.s(28)

    padding: 0
    spacing: Theme.gapXS

    contentItem: Text {
        // 勾选标记占位（checkable 时统一留出 ✓ 的空间）
        leftPadding: control.checkable ? Theme.gapL : Theme.gapS
        rightPadding: Theme.gapS
        text: control.text
        font.pixelSize: Theme.fontBody
        color: control.checkable && control.checked ? Theme.primary : Theme.textPrimary
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: Theme.gapS
        y: (control.height - height) / 2
        text: "✓"
        visible: control.checkable && control.checked
        color: Theme.primary
        font.pixelSize: Theme.fontBody
    }

    background: Rectangle {
        radius: Theme.radius - 2
        color: control.highlighted ? Theme.ghostHover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.durFast }
        }
    }
}
