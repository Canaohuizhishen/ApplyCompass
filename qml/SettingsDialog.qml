import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 设置面板（M4 引入；M5 布局重构 + 点外部关闭）。
// 注：使用透明自定义 header——Fusion 默认 header 的不透明底色块会盖住圆角（M4 方角元凶）。
Dialog {
    id: dialog
    objectName: "settingsDialog"

    modal: true
    title: qsTr("设置")
    anchors.centerIn: parent
    width: Theme.s(460)
    padding: Theme.gapL
    standardButtons: Dialog.NoButton
    // M5：Esc 或点击对话框外部均关闭（设置皆即时生效，无“未保存的修改”）
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    header: Label {
        text: dialog.title
        leftPadding: Theme.gapL
        rightPadding: Theme.gapL
        topPadding: Theme.gapM
        bottomPadding: 0
        font.pixelSize: Theme.fontTitle
        font.bold: true
        color: Theme.textPrimary
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusCard
        border.width: 1
        border.color: Theme.border
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
    }

    // Ctrl+滚轮缩放（与添加窗/抽屉一致；M6 补齐）
    ZoomWheelHandler { }

    // 分段控件：连体三段开关（激活段＝主色实底白字）
    component SegButton: Button {
        id: seg

        property bool active: false

        implicitHeight: Theme.s(28)
        leftPadding: Theme.gapM
        rightPadding: Theme.gapM
        font.pixelSize: Theme.fontBody

        contentItem: Text {
            text: seg.text
            font: seg.font
            color: seg.active ? Theme.textOnPrimary : Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: Theme.radius - 2
            color: seg.active ? Theme.primary
                 : seg.hovered || seg.pressed ? Theme.softBgHover
                 : "transparent"
            Behavior on color {
                ColorAnimation { duration: Theme.durFast }
            }
        }
    }

    // 左侧统一标签列
    component RowLabel: Label {
        Layout.preferredWidth: Theme.s(56)
        Layout.alignment: Qt.AlignVCenter
        color: Theme.textSecondary
        font.pixelSize: Theme.fontBody
    }

    ColumnLayout {
        width: dialog.availableWidth
        spacing: Theme.gapM

        // ---- 主题 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapM

            RowLabel { text: qsTr("主题") }
            Rectangle {
                radius: Theme.radius
                color: Theme.softBg
                implicitHeight: Theme.s(32)
                implicitWidth: segRow.width + Theme.gapXS * 2
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: Theme.gapXS

                    SegButton {
                        objectName: "themeSystemButton"
                        text: qsTr("跟随系统")
                        active: App.themePreference === "system"
                        onClicked: App.setThemePreference("system")
                    }
                    SegButton {
                        objectName: "themeLightButton"
                        text: qsTr("浅色")
                        active: App.themePreference === "light"
                        onClicked: App.setThemePreference("light")
                    }
                    SegButton {
                        objectName: "themeDarkButton"
                        text: qsTr("深色")
                        active: App.themePreference === "dark"
                        onClicked: App.setThemePreference("dark")
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ---- 缩放 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapM

            RowLabel { text: qsTr("缩放") }
            Label {
                text: Math.round(App.uiZoom * 100) + "%"
                font.pixelSize: Theme.fontBody
                font.bold: true
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
            AppButton {
                objectName: "resetZoomButton"
                variant: "soft"
                text: qsTr("恢复 100%")
                enabled: Math.abs(App.uiZoom - 1.0) > 0.001
                onClicked: App.setUiZoom(1.0)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        // ---- 数据 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapM

            RowLabel { text: qsTr("数据") }
            AppButton {
                objectName: "openDataFolderButton"
                variant: "soft"
                text: qsTr("数据目录")
                onClicked: App.openDataFolder()
            }
            AppButton {
                objectName: "openBackupsFolderButton"
                variant: "soft"
                text: qsTr("备份目录")
                onClicked: App.openBackupsFolder()
            }
            AppButton {
                objectName: "backupNowButton"
                variant: "soft"
                text: qsTr("立即备份")
                onClicked: App.backupNow()
            }
            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        // ---- 关于 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapM

            RowLabel { text: qsTr("关于") }
            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("ApplyCompass v%1 ｜ 本地记录 %2 条").arg(App.version).arg(App.recordCount())
                font.pixelSize: Theme.fontSmall
                color: Theme.textTertiary
                elide: Text.ElideRight
            }
        }

        // ---- 底部：完成 ----
        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }
            AppButton {
                objectName: "closeSettingsButton"
                variant: "primary"
                text: qsTr("完成")
                onClicked: dialog.close()
            }
        }
    }
}
