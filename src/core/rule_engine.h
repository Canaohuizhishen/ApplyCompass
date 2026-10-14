#pragma once

#include "core/records.h"

namespace applycompass {

// 状态迁移的纯逻辑（设计文档 §5 自动规则总表）。
// 只改传入的记录对象；持久化、时间线记录、模型刷新由调用方负责。
class RuleEngine
{
public:
    struct Transition
    {
        enum Move { None, ToApplied, ToPending };

        bool statusChanged = false;    // 状态值确实变化（空↔非空 或 值不同）
        bool applyDateSet = false;     // 投递日期 空→今天
        bool statusUpdatedSet = false; // 状态更新 → 今天
        Move move = None;
    };

    // 应用状态变更。newSortIndex 仅用于「空→非空」挪入已投区尾；today 显式传入以便测试。
    //  - 填状态（空→非空）：投递日期为空则置今天；状态更新=今天；入已投区尾；记时间线
    //  - 改状态（非空→非空）：仅 状态更新=今天
    //  - 清空（非空→空）：退回待投区；投递日期、状态更新、sortIndex 保留
    //  - 无变化（含空→空）：不动
    static Transition applyStatusChange(ApplicationRecord &rec,
                                        const QString &newStatus,
                                        const QDate &today,
                                        qint64 newSortIndex);
};

} // namespace applycompass
