import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 设置面板（M4）：主题三态 / 缩放 / 数据维护 / 关于。
// 注：使用透明自定义 header——Fusion 默认 header 的不透明底色块会盖住圆角（M4 方角元凶）。
Dialog {
    id: dialog
    objectName: "settingsDialog"

    modal: true
    title: qsTr("设置")
    anchors.centerIn: parent
    width: Theme.s(480)
    padding: Theme.gapL
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape

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

    component SectionLabel: Label {
        font.pixelSize: Theme.fontSmall
        font.bold: true
        color: Theme.textSecondary
    }

    ColumnLayout {
        spacing: Theme.gapM

        SectionLabel { text: qsTr("主题") }
        RowLayout {
            spacing: Theme.gapS
            AppButton {
                objectName: "themeSystemButton"
                variant: App.themePreference === "system" ? "primary" : "soft"
                text: qsTr("跟随系统")
                onClicked: App.setThemePreference("system")
            }
            AppButton {
                objectName: "themeLightButton"
                variant: App.themePreference === "light" ? "primary" : "soft"
                text: qsTr("浅色")
                onClicked: App.setThemePreference("light")
            }
            AppButton {
                objectName: "themeDarkButton"
                variant: App.themePreference === "dark" ? "primary" : "soft"
                text: qsTr("深色")
                onClicked: App.setThemePreference("dark")
            }
            Item { Layout.fillWidth: true }
        }

        SectionLabel { text: qsTr("缩放") }
        RowLayout {
            spacing: Theme.gapS
            Label {
                text: Math.round(App.uiZoom * 100) + "%"
                font.pixelSize: Theme.fontBody
                font.bold: true
                color: Theme.textPrimary
            }
            AppButton {
                objectName: "resetZoomButton"
                variant: "soft"
                text: qsTr("恢复 100%")
                enabled: Math.abs(App.uiZoom - 1.0) > 0.001
                onClicked: App.setUiZoom(1.0)
            }
            Item { Layout.fillWidth: true }
        }

        SectionLabel { text: qsTr("数据") }
        RowLayout {
            spacing: Theme.gapS
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

        SectionLabel { text: qsTr("关于") }
        Label {
            text: qsTr("投递罗盘 · ApplyCompass  v%1 ｜ 本地记录 %2 条 ｜ 数据仅存本机")
                  .arg(App.version).arg(App.recordCount())
            font.pixelSize: Theme.fontSmall
            color: Theme.textTertiary
        }

        RowLayout {
            Item { Layout.fillWidth: true }
            AppButton {
                objectName: "closeSettingsButton"
                variant: "ghost"
                icon.source: "icons/close.svg"
                icon.color: Theme.textPrimary
                onClicked: dialog.close()
            }
        }
    }
}
