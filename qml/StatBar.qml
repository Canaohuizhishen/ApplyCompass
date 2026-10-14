import QtQuick

import ApplyCompass

// 顶栏统计条（设计文档 §3.1）：总投递 | 进行中 | 已挂 | Offer | 待跟进。
Row {
    id: root
    objectName: "statBar"
    spacing: 14

    component Sep: Text {
        text: "｜"
        color: "#c8c8c8"
        font.pixelSize: 13
    }
    component Stat: Text {
        font.pixelSize: 13
        color: "#333333"
    }

    Stat { text: qsTr("总投递 ") + App.model.totalApplied }
    Sep { }
    Stat { text: qsTr("进行中 ") + App.model.inProgress }
    Sep { }
    Stat { text: qsTr("已挂 ") + App.model.rejected }
    Sep { }
    Stat { text: "Offer " + App.model.offers }
    Sep { }
    Stat {
        objectName: "followUpStat"
        text: qsTr("⚠ 待跟进 ") + App.model.followUpDue
        color: App.model.followUpDue > 0 ? "#b5651d" : "#999999"
    }
}
