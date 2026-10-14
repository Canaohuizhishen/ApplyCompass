import QtQuick
import QtQuick.Effects

import ApplyCompass

// 顶栏统计（§3.1）：胶囊 chips + 缩放指示（Ctrl+滚轮；点击恢复 100%）。
Row {
    id: root
    objectName: "statBar"
    spacing: Theme.gapS

    component Chip: Rectangle {
        id: chip

        radius: Theme.radius
        color: Theme.ghostHover
        implicitWidth: content.implicitWidth + Theme.gapM * 2
        implicitHeight: Theme.s(28)

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        property alias label: labelText.text
        property alias value: valueText.text
        property color valueColor: Theme.textPrimary
        property bool clickable: false
        property string iconSource: ""
        signal clicked()

        Row {
            id: content
            anchors.centerIn: parent
            spacing: Theme.gapXS

            // 注意：Row 位置器忽略带 anchors 的子项——图标经固定尺寸 Item 包装、文本自然尺寸
            Item {
                width: chip.iconSource !== "" ? Theme.s(13) : 0
                height: Theme.s(13)
                visible: chip.iconSource !== ""

                Image {
                    id: chipIcon
                    anchors.fill: parent
                    source: chip.iconSource
                    sourceSize.width: Theme.s(13)
                    sourceSize.height: Theme.s(13)
                }
                MultiEffect {
                    anchors.fill: chipIcon
                    source: chipIcon
                    colorization: 1.0
                    colorizationColor: chip.valueColor
                }
            }
            Text {
                id: labelText
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
            }
            Text {
                id: valueText
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: chip.valueColor
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: chip.clickable
            cursorShape: chip.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.clicked()
        }
    }

    Chip { label: qsTr("总投递"); value: "" + App.model.totalApplied }
    Chip { label: qsTr("进行中"); value: "" + App.model.inProgress }
    Chip { label: qsTr("已挂"); value: "" + App.model.rejected }
    Chip { label: "Offer"; value: "" + App.model.offers }
    Chip {
        objectName: "followUpChip"
        label: qsTr("待跟进")
        iconSource: "icons/warn.svg"
        value: "" + App.model.followUpDue
        valueColor: App.model.followUpDue > 0 || App.model.followUpOnly
                    ? Theme.followUpText : Theme.textTertiary
        color: App.model.followUpOnly || App.model.followUpDue > 0
               ? Theme.followUpBg : Theme.ghostHover
        border.width: App.model.followUpOnly ? 1 : 0
        border.color: Theme.followUpAccent
        clickable: true
        onClicked: App.model.toggleFollowUpFilter()
    }

    Item {
        width: Theme.gapS
        height: 1
    }

    Text {
        objectName: "zoomIndicator"
        text: Math.round(App.uiZoom * 100) + "%"
        font.pixelSize: Theme.fontSmall
        color: Theme.textSecondary
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: App.setUiZoom(1.0)
        }
    }
}
