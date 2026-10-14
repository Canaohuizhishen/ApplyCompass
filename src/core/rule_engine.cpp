#include "core/rule_engine.h"

namespace applycompass {

RuleEngine::Transition RuleEngine::applyStatusChange(ApplicationRecord &rec,
                                                     const QString &newStatus,
                                                     const QDate &today,
                                                     qint64 newSortIndex)
{
    Transition t;
    const QString old = rec.status;
    if (old == newStatus)
        return t; // 无变化（含 空→空）：不动

    t.statusChanged = true;
    rec.status = newStatus;

    if (!newStatus.isEmpty()) {
        if (rec.applyDate.isNull()) {          // 投递日期为空才补（已有日期保留：场景 3 判定）
            rec.applyDate = today;
            t.applyDateSet = true;
        }
        rec.statusUpdated = today;             // 状态更新=变更当日（改状态仅此项）
        t.statusUpdatedSet = true;
        if (old.isEmpty()) {                   // 填状态：入已投区尾
            rec.sortIndex = newSortIndex;
            t.move = Transition::ToApplied;
        }
    } else {
        t.move = Transition::ToPending;        // 清空：退回待投区；日期、sortIndex 保留
    }
    return t;
}

} // namespace applycompass
