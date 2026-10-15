import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ApplyCompass

// 添加 / 详情共用表单（设计文档 §3.2 / §3.3）。
// 外部通过 reset() / loadFrom(map) / collect() / valid 驱动。
ColumnLayout {
    id: form
    objectName: "recordForm"

    spacing: Theme.gapS

    // M6.2：表单内空白/标签点击（未被控件消费）→ 收回字段焦点（详情抽屉与添加对话框共用）
    TapHandler {
        onTapped: form.forceActiveFocus()
    }

    // 字段标签统一样式
    component FieldLabel: Label {
        font.pixelSize: Theme.fontSmall
        color: Theme.textSecondary
    }

    // 多行文本域的滚动包装（M6.1）：自管 Flickable 替代 ScrollView。
    // 滚轮委派策略（实测：Qt 不消费与 flickableDirection 不符的滚轮）：
    //  未聚焦（或域内容装得下）→ HorizontalFlick：纵向滚轮穿透给外层页面；
    //  聚焦且可滚 → VerticalFlick：域内滚动。
    component FieldScroll: Flickable {
        id: fieldScroll

        property Item fieldItem: null // 域内文本域（由其 activeFocus 门控方向）

        contentWidth: width
        contentHeight: fieldItem ? fieldItem.implicitHeight : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: fieldItem && fieldItem.activeFocus
                            && contentHeight > height + 1
                            ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        ScrollBar.vertical: AppScrollBar { policy: ScrollBar.AsNeeded }

        // 注意（M7）：本层不挂 ZoomWheelHandler——它与外层 formScroll 的捕获层会构成
        // 同一事件路径上的嵌套，实测双跳（每个 handler 都会收到并各自缩放）。单捕获层
        // 约束下：未聚焦穿透到 formScroll 层缩放；聚焦且可滚时本 Flickable 按 M6.1
        // 语义消费 Ctrl+滚轮为域内滚动（已知边界，见设计文档 §16）。
    }

    readonly property string companyText: companyField.text
    readonly property string linkText: linkField.text

    // 状态含（空）= 待投；索引 0 表示空，其余对应 App.statusOptions
    readonly property var statusModel: [qsTr("（空）")].concat(App.statusOptions)
    function statusValue() {
        return statusCombo.currentIndex <= 0 ? "" : App.statusOptions[statusCombo.currentIndex - 1]
    }
    function statusIndexFor(value) {
        return value === "" || value === undefined ? 0 : App.statusOptions.indexOf(value) + 1
    }

    // 旧数据可能有组合值（如 "C++系统开发 / C++服务端开发"）不在列表 → 追加显示避免丢失
    property string extraChannel: ""
    property string extraResume: ""
    readonly property var channelModel: extraChannel !== ""
                                           ? App.channelOptions.concat([extraChannel])
                                           : App.channelOptions
    readonly property var resumeModel: extraResume !== ""
                                           ? App.resumeVersionOptions.concat([extraResume])
                                           : App.resumeVersionOptions

    readonly property bool offered: statusValue() === "Offer"

    readonly property bool dateValid: {
        const t = applyDateField.text.trim()
        if (t === "")
            return true
        return /^\d{4}[-/]\d{1,2}[-/]\d{1,2}$/.test(t) && !isNaN(Date.parse(t))
    }
    readonly property bool valid: companyField.text.trim() !== ""
                                  && positionField.text.trim() !== ""
                                  && dateValid

    // ---- 基础信息 ----
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: Theme.gapM
        rowSpacing: Theme.gapS

        FieldLabel { text: qsTr("公司 *") }
        AppTextField {
            id: companyField
            objectName: "companyField"
            Layout.fillWidth: true
            placeholderText: qsTr("公司名称")
        }
        FieldLabel { text: qsTr("岗位名称 *") }
        AppTextField {
            id: positionField
            objectName: "positionField"
            Layout.fillWidth: true
            placeholderText: qsTr("岗位名称")
        }

        FieldLabel { text: qsTr("类型") }
        AppComboBox {
            id: kindCombo
            objectName: "kindCombo"
            Layout.fillWidth: true
            model: App.kindOptions
            currentIndex: 1
        }
        FieldLabel { text: qsTr("地区") }
        AppTextField {
            id: regionField
            objectName: "regionField"
            Layout.fillWidth: true
            placeholderText: qsTr("如：成都 / 北京")
        }

        FieldLabel { text: qsTr("渠道") }
        AppComboBox {
            id: channelCombo
            objectName: "channelCombo"
            Layout.fillWidth: true
            model: form.channelModel
            currentIndex: -1
        }
        FieldLabel { text: qsTr("简历版本") }
        AppComboBox {
            id: resumeCombo
            objectName: "resumeCombo"
            Layout.fillWidth: true
            model: form.resumeModel
            currentIndex: -1
        }

        FieldLabel { text: qsTr("投递日期") }
        AppTextField {
            id: applyDateField
            objectName: "applyDateField"
            Layout.fillWidth: true
            placeholderText: "yyyy-MM-dd"
            color: form.dateValid ? Theme.textPrimary : Theme.danger
            inputMethodHints: Qt.ImhDate
        }
        FieldLabel { text: qsTr("跟进链接") }
        AppTextField {
            id: linkField
            objectName: "linkField"
            Layout.fillWidth: true
            placeholderText: "https://…"
        }

        FieldLabel { text: qsTr("状态") }
        AppComboBox {
            id: statusCombo
            objectName: "statusCombo"
            Layout.fillWidth: true
            model: form.statusModel
            currentIndex: 0
        }
        FieldLabel {
            text: qsTr("薪资")
            visible: form.offered
        }
        AppTextField {
            id: salaryField
            objectName: "salaryField"
            Layout.fillWidth: true
            visible: form.offered
            placeholderText: qsTr("如：25×16")
        }
    }

    // ---- 多行文本 ----
    FieldLabel { text: qsTr("职责") }
    FieldScroll {
        id: dutiesScroll
        Layout.fillWidth: true
        implicitHeight: Theme.s(76)
        fieldItem: dutiesArea
        AppTextArea {
            id: dutiesArea
            objectName: "dutiesArea"
            width: dutiesScroll.width
            wrapMode: TextArea.Wrap
            placeholderText: qsTr("招聘页整段粘贴…")
        }
    }

    FieldLabel { text: qsTr("要求") }
    FieldScroll {
        id: requirementsScroll
        Layout.fillWidth: true
        implicitHeight: Theme.s(76)
        fieldItem: requirementsArea
        AppTextArea {
            id: requirementsArea
            objectName: "requirementsArea"
            width: requirementsScroll.width
            wrapMode: TextArea.Wrap
            placeholderText: qsTr("招聘页整段粘贴…")
        }
    }

    FieldLabel { text: qsTr("备注") }
    FieldScroll {
        id: notesScroll
        Layout.fillWidth: true
        implicitHeight: Theme.s(56)
        fieldItem: notesArea
        AppTextArea {
            id: notesArea
            objectName: "notesArea"
            width: notesScroll.width
            wrapMode: TextArea.Wrap
            placeholderText: qsTr("自由备注…")
        }
    }

    function reset() {
        companyField.text = ""
        positionField.text = ""
        kindCombo.currentIndex = 1
        regionField.text = ""
        extraChannel = ""
        channelCombo.currentIndex = -1
        extraResume = ""
        resumeCombo.currentIndex = -1
        applyDateField.text = ""
        linkField.text = ""
        statusCombo.currentIndex = 0
        salaryField.text = ""
        dutiesArea.text = ""
        requirementsArea.text = ""
        notesArea.text = ""
    }

    function loadFrom(map) {
        companyField.text = map.company || ""
        positionField.text = map.position || ""
        const ki = App.kindOptions.indexOf(map.kind)
        kindCombo.currentIndex = ki >= 0 ? ki : -1
        regionField.text = map.region || ""

        const ch = map.channel || ""
        const ci = App.channelOptions.indexOf(ch)
        if (ci >= 0) {
            extraChannel = ""
            channelCombo.currentIndex = ci
        } else if (ch !== "") {
            extraChannel = ch
            channelCombo.currentIndex = App.channelOptions.length
        } else {
            extraChannel = ""
            channelCombo.currentIndex = -1
        }

        const rv = map.resumeVersion || ""
        const ri = App.resumeVersionOptions.indexOf(rv)
        if (ri >= 0) {
            extraResume = ""
            resumeCombo.currentIndex = ri
        } else if (rv !== "") {
            extraResume = rv
            resumeCombo.currentIndex = App.resumeVersionOptions.length
        } else {
            extraResume = ""
            resumeCombo.currentIndex = -1
        }

        applyDateField.text = map.applyDate || ""
        linkField.text = map.link || ""
        statusCombo.currentIndex = statusIndexFor(map.status)
        salaryField.text = map.salary || ""
        dutiesArea.text = map.duties || ""
        requirementsArea.text = map.requirements || ""
        notesArea.text = map.notes || ""
    }

    // 薪资键仅当状态 = Offer 时出现：改离 Offer 时后端保留旧值（§5）
    function collect() {
        const m = {
            "company": companyField.text,
            "position": positionField.text,
            "kind": kindCombo.currentIndex >= 0 ? kindCombo.currentText : "",
            "region": regionField.text,
            "channel": channelCombo.currentIndex >= 0 ? channelCombo.currentText : "",
            "resumeVersion": resumeCombo.currentIndex >= 0 ? resumeCombo.currentText : "",
            "status": statusValue(),
            "applyDate": applyDateField.text,
            "link": linkField.text,
            "duties": dutiesArea.text,
            "requirements": requirementsArea.text,
            "notes": notesArea.text
        }
        if (offered)
            m["salary"] = salaryField.text
        return m
    }
}
