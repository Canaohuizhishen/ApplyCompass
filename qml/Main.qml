import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 主窗口：工具条（+ 添加 / 统计条）+ 两段式表格（表头 + 列表）+ 对话框/抽屉。
ApplicationWindow {
    id: window
    objectName: "mainWindow"

    width: 1320
    height: 820
    minimumWidth: 980
    minimumHeight: 560
    visible: true
    title: qsTr("投递罗盘 · ApplyCompass")

    // Ctrl+Q 退出（优雅退出会触发退出备份，§3.8）
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }

    // 数据库错误横幅（打开失败时提示，不挡操作）
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 30
        color: "#fdecea"
        visible: App.errorMessage !== ""
        z: 100
        Text {
            anchors.centerIn: parent
            text: App.errorMessage
            color: "#b3261e"
            font.pixelSize: 13
        }
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Button {
                objectName: "addButton"
                text: qsTr("+ 添加")
                onClicked: addDialog.openForNew()
            }

            Item { Layout.fillWidth: true }

            StatBar { }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 表头（列宽与行委托共用 Theme.colWidths）
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            color: "#f2f3f5"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                Repeater {
                    model: Theme.colKeys
                    Text {
                        required property int index
                        required property string modelData

                        width: Theme.colWidths[modelData]
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: Theme.colTitles[index]
                        font.pixelSize: 12
                        font.bold: true
                        color: "#666666"
                    }
                }
            }
        }

        ApplicationTable {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true
            onRowClicked: (recordId) => drawer.openFor(recordId)
        }
    }

    AddDialog { id: addDialog }

    DetailsDrawer { id: drawer }
}
