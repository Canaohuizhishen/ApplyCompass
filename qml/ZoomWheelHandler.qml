import QtQuick

import ApplyCompass

// Ctrl+滚轮缩放入口（Excel 式）。
//
// 真机回归修复（2026-10-14，Qt 语义三坑，逐一在源码/实机验证）：
//  1) acceptedModifiers 是「精确等于」语义（qquickpointerdevicehandler.cpp：
//     `event->modifiers() != acceptedModifiers → return false`）——只要 NumLock
//     等附带修饰位存在，`acceptedModifiers: Qt.ControlModifier` 会把 Ctrl+滚轮
//     整体拒绝（真机症状：按不按 Ctrl 都只滚动）。→ 不用该过滤器，改为在本
//     onWheel 内做「包含」判断（wheel.modifiers & Qt.ControlModifier）。
//  2) WheelHandler 默认 acceptedDevices=Mouse；Wayland 触摸板的平滑滚动是
//     「系统合成」事件（source ≠ MouseEventNotSynthesized），不做此设置会被
//     直接拒绝。→ 显式含 TouchPad。
//  3) blocking 默认 true（Qt 6.3+）：会在 onWheel 触发之前无条件 setAccepted，
//     非 Ctrl 的滚轮将无法回退给列表滚动。→ 置 false，只在本处显式接受。
//
// 约束（M7 再确认）：本 handler 必须保证「同一事件路径上有且只有一个」——
// 嵌套多层时每个都会收到 onWheel 并各自缩放（实测双跳 +0.2/格，accept 标记
// 无法区分先后：进入 onWheel 时 accepted 恒为 true）。抽屉/对话框因此改为
// 分区挂载（标题行 / 表单滚区 / 底栏各一个），不设根级捕获层。
WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    blocking: false

    onWheel: (wheel) => {
        if (!(wheel.modifiers & Qt.ControlModifier))
            return // 放行：交给列表/弹层自身滚动
        if (wheel.angleDelta.y === 0 && wheel.pixelDelta.y === 0)
            return
        App.zoomByWheelDeltas(wheel.angleDelta.y, wheel.pixelDelta.y)
        wheel.accepted = true
    }
}
