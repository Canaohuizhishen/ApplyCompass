import QtQuick
import QtQuick.Templates as T

import ApplyCompass

// 圆角细滚动条（M4 自绘皮肤）——基于 ScrollBar 模板；结构参考 Qt Basic 样式，
// 常态隐现（活动时渐显、静止后渐隐），把手为主色系细圆条。
T.ScrollBar {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: 2
    visible: control.policy !== T.ScrollBar.AlwaysOff
    minimumSize: orientation === Qt.Horizontal ? height / width : width / height

    contentItem: Rectangle {
        implicitWidth: control.interactive ? Theme.s(6) : Theme.s(2)
        implicitHeight: control.interactive ? Theme.s(6) : Theme.s(2)

        radius: width / 2
        color: control.pressed ? Qt.darker(Theme.scrollThumb, 1.15) : Theme.scrollThumb
        opacity: 0.0

        states: State {
            name: "active"
            when: control.policy === T.ScrollBar.AlwaysOn || (control.active && control.size < 1.0)
            PropertyChanges { control.contentItem.opacity: 0.7 }
        }

        transitions: Transition {
            from: "active"
            SequentialAnimation {
                PauseAnimation { duration: 450 }
                NumberAnimation { target: control.contentItem; duration: 200; property: "opacity"; to: 0.0 }
            }
        }
    }
}
