import QtQuick
import QtTest
import ApplyCompass

// M1 验收场景 1–6 的 UI 链路测试（QuickTest，等价 qmltestrunner）。
// 每个用例前清空数据库（数据目录由 quicktest_main.cpp 指向临时目录）。
TestCase {
    id: tc
    name: "ApplyCompassM1Scenarios"
    when: true

    property var win: null

    Component {
        id: mainComp
        Main { }
    }

    function initTestCase() {
    }

    function init() {
        App.deleteAllRecords()
        // createTemporaryObject 的生命周期＝当前测试函数：每个用例全新窗口（含布局重新成型）
        win = createTemporaryObject(mainComp, tc, { "visible": true })
        verify(win !== null)
        waitForRendering(win.contentItem)
        wait(50) // 给 ListView 一个事件循环周期实例化委托
    }

    function cleanup() {
        const drawer = win ? findChild(win, "detailsDrawer") : null
        if (drawer && drawer.opened)
            drawer.close()
        const dlg = win ? findChild(win, "addDialog") : null
        if (dlg && dlg.opened)
            dlg.close()
        if (win)
            waitForRendering(win.contentItem)
    }

    function todayIso() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd")
    }

    // 行委托：objectName 逐行唯一（rowDelegate_<id>），带重试等待实例化。
    // 注意：必须从 win.contentItem 找（Window 无 children，win 起点找不到委托）。
    function rowItem(recordId, timeout) {
        const deadline = Date.now() + (timeout || 3000)
        while (Date.now() < deadline) {
            const item = findChild(win.contentItem, "rowDelegate_" + recordId)
            if (item) {
                waitForRendering(win.contentItem)
                return item
            }
            wait(50)
        }
        return null
    }

    // 单击状态块 → 菜单 → 选择状态（返回是否点到目标项）
    function clickStatusViaMenu(statusBlock, statusText) {
        mouseClick(statusBlock)
        const menu = findChild(statusBlock, "statusMenu")
        if (!menu)
            return false
        tryVerify(function() { return menu.opened }, 2000)
        const item = findChild(statusBlock, "statusMenuItem_" + statusText)
        if (!item)
            return false
        mouseClick(item)
        return true
    }

    function openDrawerFor(recordId) {
        const row = rowItem(recordId)
        verify(row !== null)
        mouseClick(row)
        const drawer = findChild(win, "detailsDrawer")
        tryVerify(function() { return drawer.opened }, 2000)
        return drawer
    }

    // ---- 场景 1：新增（状态留空）→ 待投区尾 ----
    function test_scenario1_addPendingGoesToPendingTail() {
        mouseClick(findChild(win, "addButton"))
        const dlg = findChild(win, "addDialog")
        tryVerify(function() { return dlg.opened }, 2000)
        const form = findChild(dlg, "addForm")
        findChild(form, "companyField").text = "甲公司"
        findChild(form, "positionField").text = "后端开发实习生"
        const accept = findChild(dlg, "acceptButton")
        verify(accept.enabled)
        mouseClick(accept)
        tryVerify(function() { return !dlg.opened }, 2000)

        compare(App.recordCount(), 1)
        compare(App.model.totalApplied, 0) // 状态留空 → 不入已投统计
        const row0 = App.model.recordAtRow(0)
        compare(row0.company, "甲公司")
        compare(row0.status, "")
        compare(row0.applyDate, "") // 待投不写日期
    }

    // ---- 场景 2：新增（状态=初筛）→ 已投区尾 + 双日期=今天 ----
    function test_scenario2_addAppliedGetsDatesAndTail() {
        App.addRecord({ "company": "待投甲", "position": "p1" })
        mouseClick(findChild(win, "addButton"))
        const dlg = findChild(win, "addDialog")
        tryVerify(function() { return dlg.opened }, 2000)
        const form = findChild(dlg, "addForm")
        findChild(form, "companyField").text = "已投乙"
        findChild(form, "positionField").text = "岗位乙"
        findChild(form, "statusCombo").currentIndex = 1 // 初筛
        mouseClick(findChild(dlg, "acceptButton"))
        tryVerify(function() { return !dlg.opened }, 2000)

        compare(App.model.totalApplied, 1)
        compare(App.model.recordAtRow(0).company, "已投乙") // 已投区在前
        compare(App.model.recordAtRow(1).company, "待投甲")
        const d = App.recordDetails(App.model.recordAtRow(0).id)
        compare(d.status, "初筛")
        compare(d.applyDate, todayIso())
        compare(d.statusUpdated, todayIso())
        compare(App.timeline(d.id).length, 1)
    }

    // ---- 场景 3：待投行快改 → 初筛 → 跳到已投区尾 + 日期 + 时间线 ----
    function test_scenario3_pendingQuickChangeMovesToApplied() {
        App.addRecord({ "company": "拖后甲", "position": "p0" })
        const id = App.addRecord({ "company": "快改丙", "position": "p" })
        verify(id > 0)
        compare(App.model.rowOfRecord(id), 1) // 待投区尾

        const block = findChild(rowItem(id), "statusBlock")
        verify(block !== null)
        verify(clickStatusViaMenu(block, "初筛"))
        tryCompare(App.model, "totalApplied", 1)

        const d = App.recordDetails(id)
        compare(d.status, "初筛")
        compare(d.applyDate, todayIso())
        compare(d.statusUpdated, todayIso())
        compare(App.model.rowOfRecord(id), 0) // 已投区（只有它一条已投）
        compare(App.model.recordAtRow(1).company, "拖后甲") // 待投顺序不受影响
        compare(App.timeline(id).length, 1)
    }

    // ---- 场景 4：初筛→笔试 → 仅状态更新变 + 时间线 +1 ----
    function test_scenario4_changeStatusOnlyTouchesUpdated() {
        const id = App.addRecord({
            "company": "改状态丁", "position": "p",
            "status": "初筛", "applyDate": "2026-10-01"
        })
        verify(id > 0)
        const before = App.recordDetails(id)
        compare(before.applyDate, "2026-10-01")

        const block = findChild(rowItem(id), "statusBlock")
        verify(clickStatusViaMenu(block, "笔试"))

        const after = App.recordDetails(id)
        compare(after.status, "笔试")
        compare(after.applyDate, "2026-10-01") // 投递日期不动
        compare(after.statusUpdated, todayIso()) // 仅此项=今天
        compare(App.timeline(id).length, 2) // 填状态 1 + 改状态 1
    }

    // ---- 场景 5：清空状态 → 回待投区原位、日期保留 ----
    function test_scenario5_clearStatusReturnsToPending() {
        App.addRecord({ "company": "甲待", "position": "p1" }) // 待投序号 1
        const id = App.addRecord({
            "company": "乙退", "position": "p2",
            "status": "面试", "applyDate": "2026-10-02"
        }) // 待投序号 2 → 已投
        const drawer = openDrawerFor(id)
        const form = findChild(drawer, "detailForm")
        findChild(form, "statusCombo").currentIndex = 0 // （空）
        mouseClick(findChild(drawer, "saveButton"))
        tryCompare(App.model, "totalApplied", 0)

        const d = App.recordDetails(id)
        compare(d.status, "")
        compare(d.applyDate, "2026-10-02") // 日期保留
        compare(d.statusUpdated, todayIso()) // 状态更新保留（清空前=今天）
        compare(App.recordAtRow(0).company, "甲待") // 回原位（序号 2 > 1）
        compare(App.recordAtRow(1).company, "乙退")
        compare(App.timeline(id).length, 2) // 填 + 清
        drawer.close()
    }

    // ---- 场景 6：点行 → 详情抽屉全字段 + 链接 + 时间线 ----
    function test_scenario6_detailShowsEverything() {
        const id = App.addRecord({
            "company": "详情己", "position": "岗位己", "kind": "实习", "region": "成都",
            "channel": "BOSS", "resumeVersion": "C++服务端开发",
            "link": "https://example.com/job/99",
            "duties": "职责第一行\n职责第二行",
            "requirements": "要求第一行",
            "notes": "备注第一行",
            "status": "Offer", "applyDate": "2026-10-03"
        })
        const drawer = openDrawerFor(id)
        const form = findChild(drawer, "detailForm")
        compare(findChild(form, "companyField").text, "详情己")
        compare(findChild(form, "positionField").text, "岗位己")
        compare(findChild(form, "kindCombo").currentText, "实习")
        compare(findChild(form, "regionField").text, "成都")
        compare(findChild(form, "channelCombo").currentText, "BOSS")
        compare(findChild(form, "resumeCombo").currentText, "C++服务端开发")
        compare(findChild(form, "applyDateField").text, "2026-10-03")
        compare(findChild(form, "linkField").text, "https://example.com/job/99")
        compare(findChild(form, "dutiesArea").text, "职责第一行\n职责第二行")
        compare(findChild(form, "requirementsArea").text, "要求第一行")
        compare(findChild(form, "notesArea").text, "备注第一行")
        verify(findChild(drawer, "openLinkButton") !== null)
        verify(findChild(drawer, "timelineList") !== null)
        verify(App.timeline(id).length >= 1)
        drawer.close()
    }

    // ---- 薪资：仅 Offer 显示；改离后折叠但保留；回 Offer 再显示 ----
    function test_offerSalaryVisibilityAndPersistence() {
        const id = App.addRecord({
            "company": "薪资庚", "position": "p", "status": "Offer",
            "applyDate": "2026-10-04", "salary": "25×16"
        })
        const drawer = openDrawerFor(id)
        const form = findChild(drawer, "detailForm")
        const salary = findChild(form, "salaryField")
        verify(salary.visible)
        compare(salary.text, "25×16")

        // 改回非 Offer → 折叠
        findChild(form, "statusCombo").currentIndex = 1 // 初筛
        tryVerify(function() { return !salary.visible }, 2000)
        mouseClick(findChild(drawer, "saveButton"))
        tryCompare(App.model, "offers", 0)
        const d = App.recordDetails(id)
        compare(d.status, "初筛")
        compare(d.salary, "25×16") // 数据保留

        // 再改回 Offer → 重新显示且值还在
        findChild(form, "statusCombo").currentIndex = 4 // Offer
        tryVerify(function() { return salary.visible }, 2000)
        compare(salary.text, "25×16")
        drawer.close()
    }

    // ---- 统计条计数 ----
    function test_statsCounts() {
        App.addRecord({ "company": "s1", "position": "p", "status": "初筛" })
        App.addRecord({ "company": "s2", "position": "p", "status": "面试" })
        App.addRecord({ "company": "s3", "position": "p", "status": "Offer" })
        App.addRecord({ "company": "s4", "position": "p" })
        App.addRecord({ "company": "s5", "position": "p", "status": "简历挂" })
        compare(App.model.totalApplied, 4)
        compare(App.model.inProgress, 2)
        compare(App.model.offers, 1)
        compare(App.model.rejected, 1)
        compare(App.recordCount(), 5)
    }

    // ---- 配色映射 = 旧表条件格式实测值（锁定回归） ----
    function test_themeColorsMatchLegacyPalette() {
        const expected = {
            "初筛": "#E7E6E6", "笔试": "#FFE699", "面试": "#BDD7EE", "Offer": "#C6EFCE",
            "简历挂": "#FFC7CE", "笔试挂": "#FFC7CE", "面试挂": "#FFC7CE", "挂": "#FFC7CE",
            "放弃": "#D0CECE"
        }
        for (const k in expected)
            compare(Theme.statusColor(k), expected[k])
        compare(Theme.statusColor(""), "transparent")
    }
}
