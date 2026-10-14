import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角菜单面板（M4 自绘皮肤）——基于 Menu 模板；条目样式见 AppMenuItem。
// API 与 QQC2 Menu 一致（insertItem/removeItem/popup 等）。
T.Menu {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    margins: 0
    overlap: 1
    padding: Theme.gapXS

    contentItem: ListView {
        implicitHeight: contentHeight
        model: control.contentModel
        interactive: contentHeight + control.topPadding + control.bottomPadding > control.height
        clip: true
        currentIndex: control.currentIndex
        boundsBehavior: Flickable.StopAtBounds
    }

    background: Rectangle {
        implicitWidth: Theme.s(180)
        implicitHeight: Theme.s(40)
        radius: Theme.radiusCard - 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
    }
}
