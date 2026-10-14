#pragma once

#include <QList>
#include <QSqlDatabase>
#include <QString>
#include <QVector>

#include "core/records.h"

namespace applycompass {

// SQLite 单文件存储（设计文档 §3.8/§4.2）。
// 布局：<dataDir>/applycompass.db + <dataDir>/backups/applycompass_<ts>.db
class Database
{
public:
    explicit Database(const QString &dataDir);
    ~Database();

    Database(const Database &) = delete;
    Database &operator=(const Database &) = delete;

    bool open(QString *errorMessage = nullptr);
    bool isOpen() const;

    QString dataDir() const { return m_dataDir; }
    QString dbPath() const;
    QString backupsDir() const;
    QString lastError() const { return m_lastError; }

    qint64 recordCount() const;
    qint64 maxSortIndex() const;

    // 写入并回填 id / created_at / updated_at；失败返回 -1。
    qint64 insertRecord(ApplicationRecord &record);
    bool updateRecord(const ApplicationRecord &record);
    bool removeRecord(qint64 id);   // 级联删除时间线（ON DELETE CASCADE）
    bool deleteAllRecords();
    // 已投区（sort_index 升序）在前，待投区（sort_index 升序）在后。
    QVector<ApplicationRecord> loadAll() const;

    // 状态时间线
    bool addStatusEvent(qint64 applicationId, const QString &fromStatus, const QString &toStatus);
    QVector<StatusEvent> statusEvents(qint64 applicationId) const;

    // 备份：每日首启一次 + 退出一次；保留最近 keep 份。
    QString backupNow();              // 返回备份文件绝对路径；失败返回空串
    int rotateBackups(int keep = 14); // 返回删除的份数
    bool hasBackupToday() const;
    QList<QString> backupFiles() const; // 绝对路径，按时间倒序（新→旧）

private:
    bool createSchema();
    void setError(const QString &what, const QString &detail);

    QSqlDatabase m_db;
    QString m_connectionName;
    QString m_dataDir;
    QString m_lastError;
};

} // namespace applycompass
