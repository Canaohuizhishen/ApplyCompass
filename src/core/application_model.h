#pragma once

#include <QAbstractListModel>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "core/database.h"
#include "core/records.h"

namespace applycompass {

// 记录列表模型：双段排序（已投区 → 待投区，各按 sort_index 升序）、统计、状态快改。
// 一切修改走显式方法（表格内容不直接可编辑，防手滑）；UI 通过 AppController 调用。
class ApplicationModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int totalApplied READ totalApplied NOTIFY statsChanged)
    Q_PROPERTY(int inProgress READ inProgress NOTIFY statsChanged)
    Q_PROPERTY(int rejected READ rejected NOTIFY statsChanged)
    Q_PROPERTY(int offers READ offers NOTIFY statsChanged)
    Q_PROPERTY(int followUpDue READ followUpDue NOTIFY statsChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        CompanyRole,
        PositionRole,
        KindRole,
        RegionRole,
        ApplyDateTextRole,
        ChannelRole,
        StatusRole,
        StatusUpdatedTextRole,
        ResumeVersionRole,
        LinkRole,
        HasLinkRole,
        HasDutiesRole,
        HasRequirementsRole,
        HasNotesRole,
        SectionRole,       // 0 = 已投区，1 = 待投区（ListView section 用）
        IsAppliedRole,
        FollowUpDueRole,   // 初筛且状态更新 >14 天（M2 高亮用；M1 供统计）
    };
    Q_ENUM(Roles)

    explicit ApplicationModel(Database *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ---- 命令（持久化 + 规则 + 时间线 + 刷新，一站式）----
    qint64 addRecord(const QVariantMap &fields);                 // 返回新 id；失败 -1
    bool updateRecord(qint64 id, const QVariantMap &fields);     // 仅更新出现的键
    bool quickChangeStatus(qint64 id, const QString &status);    // 空串 = 清空状态
    bool removeRecord(qint64 id);
    bool deleteAllRecords();

    // ---- 查询 ----
    QVariantMap recordMap(qint64 id) const;                      // 详情/表单回填
    QVariantList timeline(qint64 id) const;                      // [{at, from, to}]
    Q_INVOKABLE int rowOfRecord(qint64 id) const;                // id → 当前行号（找不到 -1）
    Q_INVOKABLE QVariantMap recordAtRow(int row) const;          // 行号 → 全字段（含 id）
    Q_INVOKABLE int count() const { return m_records.size(); }   // 总行数（已投+待投）

    // ---- 统计（设计文档 §3.1 统计条）----
    int totalApplied() const { return m_totalApplied; }
    int inProgress() const { return m_inProgress; }
    int rejected() const { return m_rejected; }
    int offers() const { return m_offers; }
    int followUpDue() const { return m_followUpDue; }

    static bool isFollowUpDue(const ApplicationRecord &r, const QDate &today);

signals:
    void statsChanged();
    void recordChanged(qint64 id); // 抽屉刷新用

private:
    void reload();
    void recomputeStats();
    const ApplicationRecord *recordById(qint64 id) const;
    bool recordFromFields(const QVariantMap &fields, ApplicationRecord *rec) const;

    Database *m_db = nullptr;
    QVector<ApplicationRecord> m_records;
    int m_totalApplied = 0;
    int m_inProgress = 0;
    int m_rejected = 0;
    int m_offers = 0;
    int m_followUpDue = 0;
};

} // namespace applycompass
