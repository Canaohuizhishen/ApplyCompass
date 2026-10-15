import QtQuick
import QtQuick.Templates as T
import QtQuick.Effects

import ApplyCompass

// 圆角下拉框（M4 自绘皮肤）——基于 ComboBox 模板；结构与 Qt Basic 样式同构，按本项目
// 令牌重绘（圆角本体/圆角弹层/条目悬停高亮/chevron 指示器）。API 与 QQC2 ComboBox 一致。
T.ComboBox {
    id: control

    // 字号令牌：显示文本（contentItem `font: control.font`）与占位联动；不设则回落应用
    // 默认字体（固定像素，不随 zoom）——M7 修复。弹层 delegate 已走 Theme.fontBody。
    font.pixelSize: Theme.fontBody

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding,
                            implicitIndicatorWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             implicitIndicatorHeight + topPadding + bottomPadding)

    padding: Theme.gapS
    leftPadding: padding + Theme.gapXS
    rightPadding: padding + indicator.width + Theme.gapXS

    contentItem: Text {
        leftPadding: control.mirrored ? control.rightPadding : control.leftPadding
        rightPadding: control.mirrored ? control.leftPadding : control.rightPadding
        text: control.displayText
        font: control.font
        color: control.enabled
               ? (control.displayText !== "" ? Theme.textPrimary : Theme.textTertiary)
               : Theme.textTertiary
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // 指示器：chevron 图标（主题色染色）
    indicator: Item {
        x: control.mirrored ? Theme.gapS : control.width - width - Theme.gapS
        y: control.topPadding + (control.availableHeight - height) / 2
        implicitWidth: Theme.s(12)
        implicitHeight: Theme.s(12)
        width: Theme.s(12)
        height: Theme.s(12)

        Image {
            id: chevron
            anchors.fill: parent
            source: "icons/chevron-down.svg"
            sourceSize.width: Theme.s(12)
            sourceSize.height: Theme.s(12)
        }
        MultiEffect {
            anchors.fill: chevron
            source: chevron
            colorization: 1.0
            colorizationColor: Theme.textSecondary
        }
    }

    background: Rectangle {
        implicitWidth: Theme.s(110)
        implicitHeight: Theme.s(30)
        radius: Theme.radius
        color: control.enabled ? Theme.fieldBg : "transparent"
        border.width: 1
        border.color: control.activeFocus || control.popup.visible ? Theme.primary : Theme.border
        Behavior on border.color {
            ColorAnimation { duration: Theme.durFast }
        }
    }

    delegate: T.ItemDelegate {
        id: itemDelegate
        required property int index

        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: Theme.s(28)
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: control.textAt(itemDelegate.index)
            font.pixelSize: Theme.fontBody
            color: itemDelegate.highlighted || itemDelegate.hovered ? Theme.primary : Theme.textPrimary
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            leftPadding: Theme.gapS
            rightPadding: Theme.gapS
        }
        background: Rectangle {
            radius: Theme.radius - 2
            color: itemDelegate.highlighted || itemDelegate.hovered ? Theme.ghostHover : "transparent"
            Behavior on color {
                ColorAnimation { duration: Theme.durFast }
            }
        }
    }

    popup: T.Popup {
        y: control.height + Theme.gapXS
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                                 control.Window.height * 0.6)
        padding: Theme.gapXS

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
        }

        background: Rectangle {
            radius: Theme.radiusCard - 2
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
    }
}
