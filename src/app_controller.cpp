#include "app_controller.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QQmlEngine>
#include <QUrl>

#include "core/app_paths.h"
#include "core/application_model.h"
#include "core/database.h"
#include "core/records.h"

namespace {
AppController *s_instance = nullptr;
}

AppController::AppController(QObject *parent)
    : QObject(parent)
{
    initialize();
}

AppController *AppController::create(QQmlEngine *engine, QJSEngine *jsEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(jsEngine);
    if (!s_instance) {
        s_instance = new AppController;
        QQmlEngine::setObjectOwnership(s_instance, QQmlEngine::CppOwnership);
    }
    return s_instance;
}

void AppController::initialize()
{
    m_db = std::make_unique<applycompass::Database>(applycompass::resolveDataDir());
    QString err;
    if (!m_db->open(&err)) {
        m_error = tr("无法打开数据库：%1").arg(err);
        m_db.reset();
        return;
    }
    m_model = new applycompass::ApplicationModel(m_db.get(), this);

    // 每日首启备份 + 退出备份（§3.8）；空库不备份，避免堆积垃圾文件
    if (!m_db->hasBackupToday() && m_db->recordCount() > 0) {
        m_db->backupNow();
        m_db->rotateBackups(14);
    }
    if (QCoreApplication::instance()) {
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, [this]() {
            if (m_db && m_db->isOpen() && m_db->recordCount() > 0) {
                m_db->backupNow();
                m_db->rotateBackups(14);
            }
        });
    }
}

QString AppController::version() const
{
    return QStringLiteral("0.1.0");
}

applycompass::ApplicationModel *AppController::model() const
{
    return m_model;
}

QStringList AppController::statusOptions() const
{
    return applycompass::enums::Statuses;
}

QStringList AppController::channelOptions() const
{
    return applycompass::enums::Channels;
}

QStringList AppController::resumeVersionOptions() const
{
    return applycompass::enums::ResumeVersions;
}

QStringList AppController::kindOptions() const
{
    return applycompass::enums::Kinds;
}

QString AppController::errorMessage() const
{
    return m_error;
}

QVariantMap AppController::recordDetails(qint64 id) const
{
    return m_model ? m_model->recordMap(id) : QVariantMap();
}

QVariantList AppController::timeline(qint64 id) const
{
    return m_model ? m_model->timeline(id) : QVariantList();
}

int AppController::rowOfRecord(qint64 id) const
{
    return m_model ? m_model->rowOfRecord(id) : -1;
}

QVariantMap AppController::recordAtRow(int row) const
{
    return m_model ? m_model->recordAtRow(row) : QVariantMap();
}

int AppController::recordCount() const
{
    return m_model ? m_model->count() : 0;
}

qint64 AppController::addRecord(const QVariantMap &fields)
{
    return m_model ? m_model->addRecord(fields) : -1;
}

bool AppController::updateRecord(qint64 id, const QVariantMap &fields)
{
    return m_model && m_model->updateRecord(id, fields);
}

bool AppController::quickChangeStatus(qint64 id, const QString &status)
{
    return m_model && m_model->quickChangeStatus(id, status);
}

bool AppController::removeRecord(qint64 id)
{
    return m_model && m_model->removeRecord(id);
}

void AppController::deleteAllRecords()
{
    if (m_model)
        m_model->deleteAllRecords();
}

bool AppController::openLink(const QString &url) const
{
    const QString t = url.trimmed();
    if (t.isEmpty())
        return false;
    return QDesktopServices::openUrl(QUrl::fromUserInput(t));
}
