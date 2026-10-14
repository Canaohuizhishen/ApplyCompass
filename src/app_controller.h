#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <memory>

#include "core/application_model.h"

class QQmlEngine;
class QJSEngine;

// QML 门面单例（QML 名：App）。
// 负责：数据目录解析 → 开库 → 每日首启/退出备份 → 把模型与操作暴露给 QML。
class AppController : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(App)
    QML_SINGLETON
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(applycompass::ApplicationModel *model READ model CONSTANT)
    Q_PROPERTY(QStringList statusOptions READ statusOptions CONSTANT)
    Q_PROPERTY(QStringList channelOptions READ channelOptions CONSTANT)
    Q_PROPERTY(QStringList resumeVersionOptions READ resumeVersionOptions CONSTANT)
    Q_PROPERTY(QStringList kindOptions READ kindOptions CONSTANT)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit AppController(QObject *parent = nullptr);

    static AppController *create(QQmlEngine *engine, QJSEngine *jsEngine);

    QString version() const;
    applycompass::ApplicationModel *model() const;
    QStringList statusOptions() const;
    QStringList channelOptions() const;
    QStringList resumeVersionOptions() const;
    QStringList kindOptions() const;
    QString errorMessage() const;

    // ---- QML 接口 ----
    Q_INVOKABLE QVariantMap recordDetails(qint64 id) const; // 详情/表单回填（全字段）
    Q_INVOKABLE QVariantList timeline(qint64 id) const;     // 状态时间线 [{at, from, to}]
    Q_INVOKABLE int rowOfRecord(qint64 id) const;           // id → 当前行号（-1 = 不在）
    Q_INVOKABLE QVariantMap recordAtRow(int row) const;     // 行号 → 全字段（含 id）
    Q_INVOKABLE int recordCount() const;                    // 总行数
    Q_INVOKABLE qint64 addRecord(const QVariantMap &fields);
    Q_INVOKABLE bool updateRecord(qint64 id, const QVariantMap &fields);
    Q_INVOKABLE bool quickChangeStatus(qint64 id, const QString &status); // 空串 = 清空
    Q_INVOKABLE bool removeRecord(qint64 id);
    Q_INVOKABLE void deleteAllRecords();                    // 维护/测试用
    Q_INVOKABLE bool openLink(const QString &url) const;    // 系统浏览器打开

signals:
    void errorMessageChanged();

private:
    void initialize();

    std::unique_ptr<applycompass::Database> m_db;
    applycompass::ApplicationModel *m_model = nullptr;
    QString m_error;
};
