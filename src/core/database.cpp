#include "core/database.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace applycompass {

namespace {

int s_connectionCounter = 0;

QString nowIso()
{
    return QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"));
}

// 可空字段：空字符串一律存 NULL，读取端 toString() 自然得到空串。
QVariant sqlText(const QString &s)
{
    return s.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : QVariant(s);
}

QVariant sqlDate(const QDate &d)
{
    return d.isValid() ? QVariant(d.toString(Qt::ISODate))
                       : QVariant(QMetaType(QMetaType::QString));
}

QDate dateFromSql(const QVariant &v)
{
    const QString s = v.toString();
    return s.isEmpty() ? QDate() : QDate::fromString(s, Qt::ISODate);
}

} // namespace

Database::Database(const QString &dataDir)
    : m_dataDir(QDir(dataDir).absolutePath())
{
    m_connectionName = QStringLiteral("applycompass_%1").arg(++s_connectionCounter);
}

Database::~Database()
{
    if (m_db.isValid())
        m_db.close();
    m_db = QSqlDatabase(); // 先释放引用，再注销连接
    if (QSqlDatabase::contains(m_connectionName))
        QSqlDatabase::removeDatabase(m_connectionName);
}

QString Database::dbPath() const
{
    return QDir(m_dataDir).filePath(QStringLiteral("applycompass.db"));
}

QString Database::backupsDir() const
{
    return QDir(m_dataDir).filePath(QStringLiteral("backups"));
}

void Database::setError(const QString &what, const QString &detail)
{
    m_lastError = detail.isEmpty() ? what : QStringLiteral("%1：%2").arg(what, detail);
}

bool Database::open(QString *errorMessage)
{
    QDir dir;
    if (!dir.mkpath(m_dataDir) || !dir.mkpath(backupsDir())) {
        setError(QStringLiteral("无法创建数据目录"), m_dataDir);
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_db.setDatabaseName(dbPath());
    if (!m_db.open()) {
        setError(QStringLiteral("无法打开数据库"), m_db.lastError().text());
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }

    QSqlQuery pragma(m_db);
    if (!pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
        setError(QStringLiteral("启用外键失败"), pragma.lastError().text());
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }

    if (!createSchema()) {
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }
    return true;
}

bool Database::isOpen() const
{
    return m_db.isOpen();
}

bool Database::createSchema()
{
    const QStringList statements = {
        QStringLiteral("CREATE TABLE IF NOT EXISTS applications ("
                       "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "  company TEXT NOT NULL,"
                       "  position TEXT NOT NULL,"
                       "  kind TEXT CHECK (kind IN ('实习','正式')),"
                       "  region TEXT,"
                       "  apply_date TEXT,"
                       "  channel TEXT,"
                       "  status TEXT,"
                       "  status_updated TEXT,"
                       "  resume_version TEXT,"
                       "  link TEXT,"
                       "  duties TEXT,"
                       "  requirements TEXT,"
                       "  notes TEXT,"
                       "  salary TEXT,"
                       "  sort_index INTEGER NOT NULL DEFAULT 0,"
                       "  created_at TEXT,"
                       "  updated_at TEXT"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS status_events ("
                       "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "  application_id INTEGER NOT NULL"
                       "    REFERENCES applications(id) ON DELETE CASCADE,"
                       "  from_status TEXT,"
                       "  to_status TEXT,"
                       "  at TEXT"
                       ")"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_status_events_application"
                       " ON status_events(application_id)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS settings ("
                       "  key TEXT PRIMARY KEY,"
                       "  value TEXT"
                       ")"),
    };
    for (const QString &sql : statements) {
        QSqlQuery q(m_db);
        if (!q.exec(sql)) {
            setError(QStringLiteral("建表失败"), q.lastError().text());
            return false;
        }
    }
    return true;
}

qint64 Database::recordCount() const
{
    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral("SELECT COUNT(*) FROM applications")) || !q.next())
        return -1;
    return q.value(0).toLongLong();
}

qint64 Database::maxSortIndex() const
{
    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral("SELECT COALESCE(MAX(sort_index), 0) FROM applications"))
        || !q.next()) {
        return 0;
    }
    return q.value(0).toLongLong();
}

qint64 Database::insertRecord(ApplicationRecord &record)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO applications"
        " (company, position, kind, region, apply_date, channel, status, status_updated,"
        "  resume_version, link, duties, requirements, notes, salary, sort_index,"
        "  created_at, updated_at)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"));
    q.addBindValue(record.company);
    q.addBindValue(record.position);
    q.addBindValue(sqlText(record.kind));
    q.addBindValue(sqlText(record.region));
    q.addBindValue(sqlDate(record.applyDate));
    q.addBindValue(sqlText(record.channel));
    q.addBindValue(sqlText(record.status));
    q.addBindValue(sqlDate(record.statusUpdated));
    q.addBindValue(sqlText(record.resumeVersion));
    q.addBindValue(sqlText(record.link));
    q.addBindValue(sqlText(record.duties));
    q.addBindValue(sqlText(record.requirements));
    q.addBindValue(sqlText(record.notes));
    q.addBindValue(sqlText(record.salary));
    q.addBindValue(record.sortIndex);
    const QString now = nowIso();
    q.addBindValue(now);
    q.addBindValue(now);
    if (!q.exec()) {
        setError(QStringLiteral("插入失败"), q.lastError().text());
        return -1;
    }
    record.id = q.lastInsertId().toLongLong();
    record.createdAt = now;
    record.updatedAt = now;
    return record.id;
}

bool Database::updateRecord(const ApplicationRecord &record)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE applications SET"
        " company=?, position=?, kind=?, region=?, apply_date=?, channel=?, status=?,"
        " status_updated=?, resume_version=?, link=?, duties=?, requirements=?, notes=?,"
        " salary=?, sort_index=?, updated_at=?"
        " WHERE id=?"));
    q.addBindValue(record.company);
    q.addBindValue(record.position);
    q.addBindValue(sqlText(record.kind));
    q.addBindValue(sqlText(record.region));
    q.addBindValue(sqlDate(record.applyDate));
    q.addBindValue(sqlText(record.channel));
    q.addBindValue(sqlText(record.status));
    q.addBindValue(sqlDate(record.statusUpdated));
    q.addBindValue(sqlText(record.resumeVersion));
    q.addBindValue(sqlText(record.link));
    q.addBindValue(sqlText(record.duties));
    q.addBindValue(sqlText(record.requirements));
    q.addBindValue(sqlText(record.notes));
    q.addBindValue(sqlText(record.salary));
    q.addBindValue(record.sortIndex);
    q.addBindValue(nowIso());
    q.addBindValue(record.id);
    if (!q.exec()) {
        setError(QStringLiteral("更新失败"), q.lastError().text());
        return false;
    }
    return true;
}

bool Database::removeRecord(qint64 id)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM applications WHERE id = ?"));
    q.addBindValue(id);
    if (!q.exec()) {
        setError(QStringLiteral("删除失败"), q.lastError().text());
        return false;
    }
    return true;
}

bool Database::deleteAllRecords()
{
    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral("DELETE FROM applications"))) {
        setError(QStringLiteral("清空失败"), q.lastError().text());
        return false;
    }
    return true;
}

QVector<ApplicationRecord> Database::loadAll() const
{
    QVector<ApplicationRecord> result;
    QSqlQuery q(m_db);
    const QString sql = QStringLiteral(
        "SELECT id, company, position, kind, region, apply_date, channel, status,"
        " status_updated, resume_version, link, duties, requirements, notes, salary,"
        " sort_index, created_at, updated_at"
        " FROM applications"
        " ORDER BY (CASE WHEN status IS NULL OR status = '' THEN 1 ELSE 0 END) ASC,"
        "          sort_index ASC, id ASC");
    if (!q.exec(sql))
        return result;
    while (q.next()) {
        ApplicationRecord r;
        r.id = q.value(0).toLongLong();
        r.company = q.value(1).toString();
        r.position = q.value(2).toString();
        r.kind = q.value(3).toString();
        r.region = q.value(4).toString();
        r.applyDate = dateFromSql(q.value(5));
        r.channel = q.value(6).toString();
        r.status = q.value(7).toString();
        r.statusUpdated = dateFromSql(q.value(8));
        r.resumeVersion = q.value(9).toString();
        r.link = q.value(10).toString();
        r.duties = q.value(11).toString();
        r.requirements = q.value(12).toString();
        r.notes = q.value(13).toString();
        r.salary = q.value(14).toString();
        r.sortIndex = q.value(15).toLongLong();
        r.createdAt = q.value(16).toString();
        r.updatedAt = q.value(17).toString();
        result.append(r);
    }
    return result;
}

bool Database::addStatusEvent(qint64 applicationId, const QString &fromStatus, const QString &toStatus)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO status_events (application_id, from_status, to_status, at)"
        " VALUES (?,?,?,?)"));
    q.addBindValue(applicationId);
    q.addBindValue(sqlText(fromStatus));
    q.addBindValue(sqlText(toStatus));
    q.addBindValue(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")));
    if (!q.exec()) {
        setError(QStringLiteral("记录时间线失败"), q.lastError().text());
        return false;
    }
    return true;
}

QVector<StatusEvent> Database::statusEvents(qint64 applicationId) const
{
    QVector<StatusEvent> result;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT id, application_id, from_status, to_status, at"
        " FROM status_events WHERE application_id = ? ORDER BY at ASC, id ASC"));
    q.addBindValue(applicationId);
    if (!q.exec())
        return result;
    while (q.next()) {
        StatusEvent e;
        e.id = q.value(0).toLongLong();
        e.applicationId = q.value(1).toLongLong();
        e.fromStatus = q.value(2).toString();
        e.toStatus = q.value(3).toString();
        e.at = q.value(4).toString();
        result.append(e);
    }
    return result;
}

QString Database::setting(const QString &key, const QString &defaultValue) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT value FROM settings WHERE key = ?"));
    q.addBindValue(key);
    if (q.exec() && q.next()) {
        const QString value = q.value(0).toString();
        if (!value.isEmpty())
            return value;
    }
    return defaultValue;
}

bool Database::setSetting(const QString &key, const QString &value)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO settings(key, value) VALUES(?, ?)"));
    q.addBindValue(key);
    q.addBindValue(value);
    if (!q.exec()) {
        setError(QStringLiteral("写入设置失败"), q.lastError().text());
        return false;
    }
    return true;
}

QString Database::backupNow()
{
    if (!m_db.isOpen())
        return {};

    QDir backups(backupsDir());
    if (!backups.exists() && !backups.mkpath(QStringLiteral(".")))
        return {};

    const QString base = QStringLiteral("applycompass_%1")
                             .arg(QDateTime::currentDateTime().toString(
                                 QStringLiteral("yyyy-MM-dd_HHmmss")));
    QString path = backups.filePath(base + QStringLiteral(".db"));
    int dup = 1;
    while (QFile::exists(path)) // 同一秒内重复备份：追加序号
        path = backups.filePath(QStringLiteral("%1_%2.db").arg(base).arg(++dup));

    QSqlQuery q(m_db);
    QString escaped = path;
    escaped.replace(QLatin1Char('\''), QStringLiteral("''"));
    if (!q.exec(QStringLiteral("VACUUM INTO '%1'").arg(escaped))) {
        setError(QStringLiteral("备份失败"), q.lastError().text());
        return {};
    }
    return path;
}

QList<QString> Database::backupFiles() const
{
    QList<QString> files;
    QDir dir(backupsDir());
    // 文件名零填充 → 字典序即时间序；按新→旧返回
    const QFileInfoList entries =
        dir.entryInfoList({QStringLiteral("applycompass_*.db")}, QDir::Files,
                          QDir::Name | QDir::Reversed);
    files.reserve(entries.size());
    for (const QFileInfo &fi : entries)
        files.append(fi.absoluteFilePath());
    return files;
}

int Database::rotateBackups(int keep)
{
    const QList<QString> files = backupFiles();
    int removed = 0;
    for (int i = keep; i < files.size(); ++i) {
        if (QFile::remove(files.at(i)))
            ++removed;
    }
    return removed;
}

bool Database::hasBackupToday() const
{
    const QString prefix = QStringLiteral("applycompass_%1")
                               .arg(QDate::currentDate().toString(Qt::ISODate));
    QDir dir(backupsDir());
    const QStringList names =
        dir.entryList({QStringLiteral("applycompass_*.db")}, QDir::Files, QDir::NoSort);
    for (const QString &name : names) {
        if (name.startsWith(prefix))
            return true;
    }
    return false;
}

} // namespace applycompass
