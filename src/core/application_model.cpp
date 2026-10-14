#include "core/application_model.h"

#include "core/rule_engine.h"

namespace applycompass {

namespace {

bool parseDateString(const QString &s, QDate *out)
{
    const QString t = s.trimmed();
    if (t.isEmpty()) {
        *out = QDate();
        return true;
    }
    QDate d = QDate::fromString(t, Qt::ISODate);
    if (!d.isValid())
        d = QDate::fromString(t, QStringLiteral("yyyy/M/d"));
    if (!d.isValid())
        return false;
    *out = d;
    return true;
}

bool isKnownStatus(const QString &s)
{
    return s.isEmpty() || enums::Statuses.contains(s);
}

QString normalizedKind(const QString &s)
{
    return enums::Kinds.contains(s) ? s : QString();
}

} // namespace

ApplicationModel::ApplicationModel(Database *db, QObject *parent)
    : QAbstractListModel(parent)
    , m_db(db)
{
    reload();
}

int ApplicationModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_records.size();
}

QVariant ApplicationModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_records.size())
        return {};
    const ApplicationRecord &r = m_records.at(index.row());
    switch (role) {
    case IdRole:
        return r.id;
    case CompanyRole:
        return r.company;
    case PositionRole:
        return r.position;
    case KindRole:
        return r.kind;
    case RegionRole:
        return r.region;
    case ApplyDateTextRole:
        return r.applyDate.isValid() ? r.applyDate.toString(Qt::ISODate) : QString();
    case ChannelRole:
        return r.channel;
    case StatusRole:
        return r.status;
    case StatusUpdatedTextRole:
        return r.statusUpdated.isValid() ? r.statusUpdated.toString(Qt::ISODate) : QString();
    case ResumeVersionRole:
        return r.resumeVersion;
    case LinkRole:
        return r.link;
    case HasLinkRole:
        return !r.link.isEmpty();
    case HasDutiesRole:
        return !r.duties.trimmed().isEmpty();
    case HasRequirementsRole:
        return !r.requirements.trimmed().isEmpty();
    case HasNotesRole:
        return !r.notes.trimmed().isEmpty();
    case SectionRole:
        return r.isApplied() ? 0 : 1;
    case IsAppliedRole:
        return r.isApplied();
    case FollowUpDueRole:
        return isFollowUpDue(r, QDate::currentDate());
    }
    return {};
}

QHash<int, QByteArray> ApplicationModel::roleNames() const
{
    return {
        {IdRole, "id"},
        {CompanyRole, "company"},
        {PositionRole, "position"},
        {KindRole, "kind"},
        {RegionRole, "region"},
        {ApplyDateTextRole, "applyDateText"},
        {ChannelRole, "channel"},
        {StatusRole, "status"},
        {StatusUpdatedTextRole, "statusUpdatedText"},
        {ResumeVersionRole, "resumeVersion"},
        {LinkRole, "link"},
        {HasLinkRole, "hasLink"},
        {HasDutiesRole, "hasDuties"},
        {HasRequirementsRole, "hasRequirements"},
        {HasNotesRole, "hasNotes"},
        {SectionRole, "section"},
        {IsAppliedRole, "isApplied"},
        {FollowUpDueRole, "followUpDue"},
    };
}

void ApplicationModel::reload()
{
    beginResetModel();
    m_records = m_db ? m_db->loadAll() : QVector<ApplicationRecord>();
    endResetModel();
    recomputeStats();
}

void ApplicationModel::recomputeStats()
{
    m_totalApplied = m_inProgress = m_rejected = m_offers = m_followUpDue = 0;
    const QDate today = QDate::currentDate();
    for (const ApplicationRecord &r : m_records) {
        if (!r.isApplied())
            continue;
        ++m_totalApplied;
        if (enums::InProgressStatuses.contains(r.status))
            ++m_inProgress;
        if (enums::RejectedStatuses.contains(r.status))
            ++m_rejected;
        if (r.status == enums::Offer)
            ++m_offers;
        if (isFollowUpDue(r, today))
            ++m_followUpDue;
    }
    emit statsChanged();
}

bool ApplicationModel::isFollowUpDue(const ApplicationRecord &r, const QDate &today)
{
    return r.status == QStringLiteral("初筛") && r.statusUpdated.isValid()
           && r.statusUpdated.daysTo(today) > 14;
}

const ApplicationRecord *ApplicationModel::recordById(qint64 id) const
{
    for (const ApplicationRecord &r : m_records) {
        if (r.id == id)
            return &r;
    }
    return nullptr;
}

bool ApplicationModel::recordFromFields(const QVariantMap &fields, ApplicationRecord *rec) const
{
    rec->company = fields.value(QStringLiteral("company")).toString().trimmed();
    rec->position = fields.value(QStringLiteral("position")).toString().trimmed();
    if (rec->company.isEmpty() || rec->position.isEmpty())
        return false;
    rec->kind = normalizedKind(fields.value(QStringLiteral("kind")).toString().trimmed());
    rec->region = fields.value(QStringLiteral("region")).toString().trimmed();
    rec->channel = fields.value(QStringLiteral("channel")).toString().trimmed();
    rec->resumeVersion = fields.value(QStringLiteral("resumeVersion")).toString().trimmed();
    rec->link = fields.value(QStringLiteral("link")).toString().trimmed();
    rec->duties = fields.value(QStringLiteral("duties")).toString();
    rec->requirements = fields.value(QStringLiteral("requirements")).toString();
    rec->notes = fields.value(QStringLiteral("notes")).toString();
    rec->salary = fields.value(QStringLiteral("salary")).toString().trimmed();
    return parseDateString(fields.value(QStringLiteral("applyDate")).toString(), &rec->applyDate);
}

qint64 ApplicationModel::addRecord(const QVariantMap &fields)
{
    if (!m_db)
        return -1;
    ApplicationRecord rec;
    if (!recordFromFields(fields, &rec)) // 公司/岗位必填；日期格式校验
        return -1;
    const QString newStatus = fields.value(QStringLiteral("status")).toString().trimmed();
    if (!isKnownStatus(newStatus))
        return -1;

    const qint64 next = m_db->maxSortIndex() + 1;
    if (!newStatus.isEmpty()) {
        // 空→非空：补双日期 + 入已投区尾（§5）
        RuleEngine::applyStatusChange(rec, newStatus, QDate::currentDate(), next);
    } else {
        rec.sortIndex = next; // 待投区尾
    }

    const qint64 id = m_db->insertRecord(rec);
    if (id < 0)
        return -1;
    if (!rec.status.isEmpty())
        m_db->addStatusEvent(id, QString(), rec.status);

    reload();
    emit recordChanged(id);
    return id;
}

bool ApplicationModel::updateRecord(qint64 id, const QVariantMap &fields)
{
    if (!m_db)
        return false;
    const ApplicationRecord *cur = recordById(id);
    if (!cur)
        return false;

    const QString oldStatus = cur->status;
    ApplicationRecord rec = *cur;

    // 仅更新出现的键（薪资字段在非 Offer 时不出现在表单里 → 数据保留）
    auto text = [&fields](const char *key) { return fields.value(QLatin1String(key)).toString(); };
    if (fields.contains(QStringLiteral("company")))
        rec.company = text("company").trimmed();
    if (fields.contains(QStringLiteral("position")))
        rec.position = text("position").trimmed();
    if (fields.contains(QStringLiteral("kind")))
        rec.kind = normalizedKind(text("kind").trimmed());
    if (fields.contains(QStringLiteral("region")))
        rec.region = text("region").trimmed();
    if (fields.contains(QStringLiteral("channel")))
        rec.channel = text("channel").trimmed();
    if (fields.contains(QStringLiteral("resumeVersion")))
        rec.resumeVersion = text("resumeVersion").trimmed();
    if (fields.contains(QStringLiteral("link")))
        rec.link = text("link").trimmed();
    if (fields.contains(QStringLiteral("duties")))
        rec.duties = text("duties");
    if (fields.contains(QStringLiteral("requirements")))
        rec.requirements = text("requirements");
    if (fields.contains(QStringLiteral("notes")))
        rec.notes = text("notes");
    if (fields.contains(QStringLiteral("salary")))
        rec.salary = text("salary").trimmed();
    if (fields.contains(QStringLiteral("applyDate"))) {
        QDate d;
        if (!parseDateString(text("applyDate"), &d))
            return false; // 手改日期解析失败 → 整次更新拒绝
        rec.applyDate = d;
    }
    if (rec.company.isEmpty() || rec.position.isEmpty())
        return false;

    QString newStatus = oldStatus;
    if (fields.contains(QStringLiteral("status"))) {
        newStatus = text("status").trimmed();
        if (!isKnownStatus(newStatus))
            return false;
    }

    if (newStatus != oldStatus) {
        const qint64 next = m_db->maxSortIndex() + 1;
        RuleEngine::applyStatusChange(rec, newStatus, QDate::currentDate(), next);
    } else {
        rec.status = newStatus;
    }

    if (!m_db->updateRecord(rec))
        return false;
    if (newStatus != oldStatus)
        m_db->addStatusEvent(id, oldStatus, newStatus);

    reload();
    emit recordChanged(id);
    return true;
}

bool ApplicationModel::quickChangeStatus(qint64 id, const QString &status)
{
    QVariantMap fields;
    fields.insert(QStringLiteral("status"), status.trimmed());
    return updateRecord(id, fields);
}

bool ApplicationModel::removeRecord(qint64 id)
{
    if (!m_db || !m_db->removeRecord(id))
        return false;
    reload();
    emit recordChanged(id);
    return true;
}

bool ApplicationModel::deleteAllRecords()
{
    if (!m_db || !m_db->deleteAllRecords())
        return false;
    reload();
    return true;
}

QVariantMap ApplicationModel::recordMap(qint64 id) const
{
    QVariantMap map;
    const ApplicationRecord *r = recordById(id);
    if (!r)
        return map;
    map.insert(QStringLiteral("id"), r->id);
    map.insert(QStringLiteral("company"), r->company);
    map.insert(QStringLiteral("position"), r->position);
    map.insert(QStringLiteral("kind"), r->kind);
    map.insert(QStringLiteral("region"), r->region);
    map.insert(QStringLiteral("applyDate"),
               r->applyDate.isValid() ? r->applyDate.toString(Qt::ISODate) : QString());
    map.insert(QStringLiteral("channel"), r->channel);
    map.insert(QStringLiteral("status"), r->status);
    map.insert(QStringLiteral("statusUpdated"),
               r->statusUpdated.isValid() ? r->statusUpdated.toString(Qt::ISODate) : QString());
    map.insert(QStringLiteral("resumeVersion"), r->resumeVersion);
    map.insert(QStringLiteral("link"), r->link);
    map.insert(QStringLiteral("duties"), r->duties);
    map.insert(QStringLiteral("requirements"), r->requirements);
    map.insert(QStringLiteral("notes"), r->notes);
    map.insert(QStringLiteral("salary"), r->salary);
    return map;
}

int ApplicationModel::rowOfRecord(qint64 id) const
{
    for (int i = 0; i < m_records.size(); ++i) {
        if (m_records.at(i).id == id)
            return i;
    }
    return -1;
}

QVariantMap ApplicationModel::recordAtRow(int row) const
{
    if (row < 0 || row >= m_records.size())
        return {};
    return recordMap(m_records.at(row).id);
}

QVariantList ApplicationModel::timeline(qint64 id) const
{    QVariantList list;
    if (!m_db)
        return list;
    const QVector<StatusEvent> events = m_db->statusEvents(id);
    list.reserve(events.size());
    for (const StatusEvent &e : events) {
        QVariantMap m;
        m.insert(QStringLiteral("at"), e.at);
        m.insert(QStringLiteral("from"), e.fromStatus);
        m.insert(QStringLiteral("to"), e.toStatus);
        list.append(m);
    }
    return list;
}

} // namespace applycompass
