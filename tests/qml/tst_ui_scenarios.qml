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
        App.model.clearFilters()
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

    // ---- 整行状态配色（M3）：浅色=旧表纯色；深色=合成色（非纯色）；待投=白 ----
    function test_rowStatusColors() {
        App.setDarkModeOverride(0) // 锁定浅色（测试环境 colorScheme 不定，显式确定）

        const idGray = App.addRecord({ "company": "灰行", "position": "p", "status": "初筛", "applyDate": "2026-10-01" })
        const idOffer = App.addRecord({ "company": "绿行", "position": "p", "status": "Offer", "applyDate": "2026-10-01" })
        const idPending = App.addRecord({ "company": "白行", "position": "p" })
        verify(idGray > 0 && idOffer > 0 && idPending > 0)

        const rowGray = rowItem(idGray)
        const rowOffer = rowItem(idOffer)
        const rowPending = rowItem(idPending)
        verify(rowGray !== null && rowOffer !== null && rowPending !== null)

        // 浅色：整行 = 旧表条件格式实测色（与导出 tst_export 同一基准）
        compare(findChild(rowGray, "rowBackground").color.toString().toUpperCase(), "#E7E6E6")
        compare(findChild(rowOffer, "rowBackground").color.toString().toUpperCase(), "#C6EFCE")
        // 待投（状态空）：白 surface，不染色
        compare(findChild(rowPending, "rowBackground").color.toString().toUpperCase(),
                Theme.surface.toString().toUpperCase())

        // 深色：同一行切换为低透明度合成色（≠ 旧表纯色、≠ 暗表面），绑定即时生效
        App.setDarkModeOverride(1)
        tryVerify(function() {
            const c = findChild(rowGray, "rowBackground").color.toString().toUpperCase()
            return c !== "#E7E6E6" && c !== "#171B23"
        })

        // 键盘选中：主色内描边 + 叠加层可见（纯色行上仍可辨）
        const table = findChild(win.contentItem, "applicationTable")
        table.currentId = idGray
        tryVerify(function() {
            return findChild(rowGray, "rowSelectedBorder").visible
                   && findChild(rowGray, "rowHoverOverlay").visible
        })

        // 恢复（不影响其余用例）：取消选中 + 回跟随系统
        table.currentId = -1
        App.setDarkModeOverride(-1)
    }

    // ---- 深浅色跟随/覆盖（M3）：令牌随 darkMode 切换；状态语义色恒定 ----
    function test_darkModeFollowOverride() {
        App.setDarkModeOverride(1)
        tryVerify(function() { return Theme.dark === true })
        compare(Theme.surface.toString().toUpperCase(), "#171B23")
        compare(Theme.statusColor("初筛"), "#E7E6E6") // 两模式下不变（旧表锚定）

        App.setDarkModeOverride(0)
        tryVerify(function() { return Theme.dark === false })
        compare(Theme.surface.toString().toUpperCase(), "#FFFFFF")

        App.setDarkModeOverride(-1)
    }

    // ---- Ctrl+C 复制（M3）：Shift 区间多选 + 锚点语义 ----
    function test_copySelectionTsv() {
        const idA = App.addRecord({ "company": "复制甲", "position": "p1", "status": "初筛", "applyDate": "2026-10-01" })
        App.addRecord({ "company": "复制乙", "position": "p2" })
        const idC = App.addRecord({ "company": "复制丙", "position": "p3" })
        const table = findChild(win.contentItem, "applicationTable")
        verify(table !== null)
        table.forceActiveFocus()
        wait(50)

        // 单行：Down → 选中已投区首行（复制甲）
        keyClick(Qt.Key_Down)
        tryVerify(function() { return table.currentId === idA })
        compare(table.selectedRange().first, table.selectedRange().last)

        // Shift+Down ×2 → 区间 0..2（复制甲..复制丙）
        keyClick(Qt.Key_Down, Qt.ShiftModifier)
        keyClick(Qt.Key_Down, Qt.ShiftModifier)
        tryVerify(function() {
            return table.selectedRange().first === 0 && table.selectedRange().last === 2
        })

        // 区间高亮：首尾行均 selected
        const rowA = rowItem(idA)
        const rowC = rowItem(idC)
        verify(rowA !== null && rowC !== null)
        tryVerify(function() { return rowA.selected && rowC.selected })

        // Ctrl+C：触发复制（TSV 内容由 tst_model.tsvTextFormat 锚定）
        keyClick(Qt.Key_C, Qt.ControlModifier)

        // 普通移动重置锚点 → 回到单行选择
        keyClick(Qt.Key_Up)
        tryVerify(function() {
            return table.selectedRange().first === table.selectedRange().last
        })
    }

    // ---- 窗口布局记忆（M3）：保存/读取往返 + 屏幕越界防护 ----
    function test_windowStateRoundtrip() {
        App.saveWindowState(120, 90, 1180, 660, false)
        let s = App.loadWindowState()
        compare(s.x, 120)
        compare(s.y, 90)
        compare(s.width, 1180)
        compare(s.height, 660)
        compare(s.maximized, false)

        // 越界位置 → 丢弃坐标（防丢窗）
        App.saveWindowState(99999, 99999, 1000, 640, false)
        s = App.loadWindowState()
        compare(s.x, -1)
        compare(s.y, -1)
        compare(s.width, 1000) // 尺寸仍恢复（≥ 最小尺寸）

        // 最大化标记往返
        App.saveWindowState(-1, -1, 1000, 640, true)
        s = App.loadWindowState()
        compare(s.maximized, true)

        // 恢复默认，避免影响后续用例建窗
        App.saveWindowState(-1, -1, 1320, 820, false)
    }

    // ---- 设置面板（M4）：主题三态往返 + 缩放复位 + 立即备份 ----
    function test_settingsPanel() {
        mouseClick(findChild(win, "settingsButton"))
        const dlg = findChild(win, "settingsDialog")
        verify(dlg !== null)
        tryVerify(function() { return dlg.opened }, 2000)

        // 主题三态：dark/light 即时联动 Theme.dark；system 只断言偏好值（具体明暗由环境决定）
        mouseClick(findChild(dlg, "themeDarkButton"))
        tryVerify(function() { return App.themePreference === "dark" && Theme.dark === true })
        mouseClick(findChild(dlg, "themeLightButton"))
        tryVerify(function() { return App.themePreference === "light" && Theme.dark === false })
        compare(Theme.surface.toString().toUpperCase(), "#FFFFFF")
        mouseClick(findChild(dlg, "themeSystemButton"))
        tryVerify(function() { return App.themePreference === "system" })

        // 缩放复位
        App.setUiZoom(1.3)
        tryVerify(function() { return findChild(dlg, "resetZoomButton").enabled })
        mouseClick(findChild(dlg, "resetZoomButton"))
        tryVerify(function() { return App.uiZoom === 1.0 })

        // 立即备份（测试数据目录为临时目录，安全）：toast 消息 + 备份目录出现文件
        mouseClick(findChild(dlg, "backupNowButton"))
        tryVerify(function() { return App.lastExportMessage.indexOf("已备份") === 0 })
        App.clearExportMessage()

        dlg.close()
        tryVerify(function() { return !dlg.opened }, 2000)
    }

    // ---- Ctrl+滚轮缩放 ----
    function test_zoomByCtrlWheelAndClamp() {
        App.setUiZoom(1.0)
        const table = findChild(win.contentItem, "applicationTable")
        verify(table !== null)

        mouseWheel(table, table.width / 2, table.height / 2, 0, 120, Qt.NoButton, Qt.ControlModifier)
        tryCompare(App, "uiZoom", 1.1)
        mouseWheel(table, table.width / 2, table.height / 2, 0, -120, Qt.NoButton, Qt.ControlModifier)
        tryCompare(App, "uiZoom", 1.0)

        for (let i = 0; i < 20; ++i)
            App.zoomBySteps(1)
        compare(App.uiZoom, 1.6) // 上限
        for (let i = 0; i < 30; ++i)
            App.zoomBySteps(-1)
        compare(App.uiZoom, 0.7) // 下限

        // 未按 Ctrl 的滚轮不触发缩放（交给列表自身滚动）
        App.setUiZoom(1.0)
        mouseWheel(table, table.width / 2, table.height / 2, 0, 120, Qt.NoButton, Qt.NoModifier)
        compare(App.uiZoom, 1.0)

        App.setUiZoom(1.0)
        compare(App.uiZoom, 1.0)
    }

    // ---- 放大后表格超宽 → 横向滚动容器生效 ----
    function test_horizontalScrollWhenZoomedIn() {
        App.setUiZoom(1.0)
        const scroll = findChild(win.contentItem, "tableScroll")
        verify(scroll !== null)
        // 100%：窗口宽（1320）≥ 表宽（≈1244），无需横滚
        tryVerify(function() { return scroll.contentWidth <= scroll.width + 1 })

        App.setUiZoom(1.5)
        tryVerify(function() { return scroll.contentWidth > scroll.width })

        App.setUiZoom(1.0)
    }

    // ---- 缩放驱动设计令牌 ----
    function test_zoomScalesThemeTokens() {
        App.setUiZoom(1.0)
        const baseWidth = Theme.colWidths.company
        const baseRow = Theme.rowHeight
        verify(baseWidth > 0 && baseRow > 0)

        App.setUiZoom(1.5)
        tryVerify(function() { return Theme.colWidths.company > baseWidth })
        compare(Theme.colWidths.company, Math.round(176 * 1.5))
        compare(Theme.rowHeight, Math.round(32 * 1.5))

        App.setUiZoom(1.0)
    }

    // ---- 快捷键与选中行（§3.7） ----
    function test_keyboardShortcuts() {
        const idA = App.addRecord({ "company": "键甲", "position": "p" })
        App.addRecord({ "company": "键乙", "position": "p" })
        const table = findChild(win.contentItem, "applicationTable")
        verify(table !== null)
        table.forceActiveFocus()
        wait(50)

        // ↑↓ 选中行
        keyClick(Qt.Key_Down)
        tryVerify(function() { return table.currentId === idA })
        keyClick(Qt.Key_Down)
        tryVerify(function() { return table.currentId !== idA && table.currentId > 0 })
        keyClick(Qt.Key_Up)
        tryVerify(function() { return table.currentId === idA })

        // 1-9：为选中行改状态
        keyClick(Qt.Key_1) // 初筛
        tryVerify(function() { return App.recordDetails(idA).status === "初筛" })
        compare(App.model.totalApplied, 1)

        // Enter：打开选中行详情
        keyClick(Qt.Key_Return)
        const drawer = findChild(win, "detailsDrawer")
        tryVerify(function() { return drawer.opened })
        drawer.close()
        wait(50)

        // n：打开添加表单（等待抽屉退场动画结束——退场期间弹层会短暂拦截按键）
        table.forceActiveFocus()
        wait(400)
        keyClick(Qt.Key_N)
        const dlg = findChild(win, "addDialog")
        tryVerify(function() { return dlg.opened })
        dlg.close()
    }

    // ---- 搜索与筛选（§3.5） ----
    function test_searchAndFilters() {
        App.addRecord({ "company": "搜索甲科技", "position": "后端开发", "region": "成都", "notes": "注意备注A" })
        App.addRecord({ "company": "搜索乙网络", "position": "客户端开发", "region": "北京" })
        App.addRecord({ "company": "其他丙", "position": "测试开发", "status": "初筛", "region": "成都" })

        // 公司 / 岗位 / 备注 / 地区 模糊匹配
        App.model.searchText = "搜索甲"
        tryVerify(function() { return App.model.count() === 1 })
        compare(App.model.recordAtRow(0).company, "搜索甲科技")
        App.model.searchText = "客户端"
        tryVerify(function() { return App.model.count() === 1 })
        App.model.searchText = "备注A"
        tryVerify(function() { return App.model.count() === 1 })
        App.model.searchText = "成都"
        tryVerify(function() { return App.model.count() === 2 })
        App.model.searchText = ""
        tryVerify(function() { return App.model.count() === 3 })

        // 地区 + 搜索叠加；分区头计数=筛选后口径（搜索甲科技为无状态记录 → 在待投区）
        App.model.regionFilter = "成都"
        tryVerify(function() { return App.model.count() === 2 })
        App.model.searchText = "搜索甲"
        tryVerify(function() { return App.model.count() === 1 })
        compare(App.model.visibleAppliedCount, 0)
        compare(App.model.visiblePendingCount, 1)

        // 清除 → 全量恢复
        App.model.clearFilters()
        tryVerify(function() { return App.model.count() === 3 })
        compare(App.model.filtersActive, false)
        compare(App.model.visiblePendingCount, 2)

        // 状态多选
        App.model.statusFilter = ["初筛", "Offer"]
        tryVerify(function() { return App.model.count() === 1 })
        compare(App.model.recordAtRow(0).company, "其他丙")
        App.model.clearFilters()

        // 顶栏「待跟进」chip 点击切换筛选
        const chip = findChild(win, "followUpChip")
        verify(chip !== null)
        mouseClick(chip)
        tryVerify(function() { return App.model.followUpOnly === true })
        mouseClick(chip)
        tryVerify(function() { return App.model.followUpOnly === false })
    }

    // ---- 导出（§3.6）：按钮触发 → 消息 + 返回结构 ----
    function test_exportViaUi() {
        App.addRecord({ "company": "导出甲", "position": "p", "status": "初筛",
                        "link": "https://example.com/job/9" })
        App.addRecord({ "company": "导出乙", "position": "p" })
        App.clearExportMessage()

        const exportButton = findChild(win, "exportButton")
        verify(exportButton !== null)
        mouseClick(exportButton)
        tryVerify(function() { return App.lastExportMessage !== "" })
        verify(App.lastExportMessage.indexOf("已导出") === 0)

        const res = App.exportAll() // 复跑校验返回结构（幂等）
        compare(res.ok, true)
        verify(res.xlsx !== "")
        verify(res.csv !== "")
    }

    // ---- 滚轮修饰键组合（真机回归锚点）----
    // 背景：acceptedModifiers 是"精确等于"语义（qquickpointerdevicehandler.cpp），
    // NumLock 等附带修饰位会把 Ctrl+滚轮整体拒绝（真机症状：按不按 Ctrl 都只滚动）。
    // 修复 = ZoomWheelHandler 改用配置（TouchPad 设备 + blocking:false）+ JS 包含判断。
    function test_zoomModifierCombos() {
        App.setUiZoom(1.0)
        const table = findChild(win.contentItem, "applicationTable")
        verify(table !== null)
        const cx = table.width / 2
        const cy = table.height / 2

        // Ctrl|Keypad（NumLock 打开场景）：修复前整体被拒
        mouseWheel(table, cx, cy, 0, 120, Qt.NoButton,
                   Qt.ControlModifier | Qt.KeypadModifier)
        tryCompare(App, "uiZoom", 1.1)
        // Ctrl|Shift：包含语义同样缩放
        mouseWheel(table, cx, cy, 0, 120, Qt.NoButton,
                   Qt.ControlModifier | Qt.ShiftModifier)
        tryCompare(App, "uiZoom", 1.2)
        // 精确 Ctrl 反向缩回
        mouseWheel(table, cx, cy, 0, -120, Qt.NoButton, Qt.ControlModifier)
        tryCompare(App, "uiZoom", 1.1)

        // 未按 Ctrl：不缩放，且回退为列表滚动（blocking:false 锚点）
        App.setUiZoom(1.0)
        for (let i = 0; i < 25; ++i)
            App.addRecord({ "company": "滚轮" + i, "position": "p" })
        wait(150)
        const list = findChild(win.contentItem, "applicationTable")
        list.contentY = 0
        wait(50)
        mouseWheel(list, cx, cy, 0, -120, Qt.NoButton, Qt.NoModifier)
        tryVerify(function() { return list.contentY > 1 }, 2000)
        compare(App.uiZoom, 1.0)

        App.setUiZoom(1.0)
    }

    // ---- 可滚动列表中的 Ctrl+滚轮（真机核心场景：列表能滚时也必须缩放）----
    // 背景：Flickable 能滚动时会先消费滚轮，祖先层 handler 拿不到事件，
    // 之前所有用例的列表都不可滚动（内容太短），因此测不到此缺陷。
    function test_zoomWithScrollableList() {
        App.setUiZoom(1.0)
        for (let i = 0; i < 60; ++i)
            App.addRecord({ "company": "缩放大列表" + i, "position": "p" })
        wait(200)

        const table = findChild(win.contentItem, "applicationTable")
        verify(table !== null)
        verify(table.contentHeight > table.height + 50) // 确保确实可滚动

        table.contentY = Math.round((table.contentHeight - table.height) / 2) // 列表中部
        wait(80)
        const y0 = table.contentY
        const cx = table.width / 2
        const cy = table.height / 2

        // 中部 + Ctrl+滚轮拉近：必须缩放，且列表不被滚动
        mouseWheel(table, cx, cy, 0, 120, Qt.NoButton, Qt.ControlModifier)
        tryCompare(App, "uiZoom", 1.1)
        compare(Math.abs(table.contentY - y0) < 1, true)

        // 中部 + Ctrl+Keypad（NumLock）同样缩放（组合锚点）
        mouseWheel(table, cx, cy, 0, 120, Qt.NoButton,
                   Qt.ControlModifier | Qt.KeypadModifier)
        tryCompare(App, "uiZoom", 1.2)

        // 普通滚轮：不缩放、照常滚动（捕获层放行）
        App.setUiZoom(1.0)
        const y1 = table.contentY
        mouseWheel(table, cx, cy, 0, -120, Qt.NoButton, Qt.NoModifier)
        tryVerify(function() { return table.contentY > y1 + 1 }, 2000)
        compare(App.uiZoom, 1.0)
    }

    // ---- 滚轮增量处理：经典 angle / 触摸板 pixel 累积（Wayland 常见 angleDelta=0） ----
    function test_zoomWheelDeltas() {
        App.setUiZoom(1.0)

        // 经典滚轮：一个刻度一步
        App.zoomByWheelDeltas(120, 0)
        tryCompare(App, "uiZoom", 1.1)
        App.zoomByWheelDeltas(-120, 0)
        tryCompare(App, "uiZoom", 1.0)

        // 触摸板像素累积：40px 一步
        App.zoomByWheelDeltas(0, 15)
        compare(App.uiZoom, 1.0)
        App.zoomByWheelDeltas(0, 15)
        compare(App.uiZoom, 1.0)
        App.zoomByWheelDeltas(0, 15) // 累积 45 → 一步（余 5）
        tryCompare(App, "uiZoom", 1.1)
        App.zoomByWheelDeltas(0, 35) // 5+35=40 → 一步
        tryCompare(App, "uiZoom", 1.2)

        // 反向累积
        App.zoomByWheelDeltas(0, -20)
        compare(App.uiZoom, 1.2)
        App.zoomByWheelDeltas(0, -25) // 累积 -45 → 一步
        tryCompare(App, "uiZoom", 1.1)
        App.zoomByWheelDeltas(0, 30) // 残留 -5+30=25，不步进
        compare(App.uiZoom, 1.1)

        // 经典滚轮重置像素累積（防混用残留）
        App.zoomByWheelDeltas(120, 0)
        tryCompare(App, "uiZoom", 1.2)
        App.zoomByWheelDeltas(0, 39) // 已重置则 39<40 不动
        compare(App.uiZoom, 1.2)

        App.setUiZoom(1.0)
    }
}
