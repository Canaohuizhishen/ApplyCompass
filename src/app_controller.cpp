#include "app_controller.h"

#include <algorithm>
#include <cmath>

#include <QClipboard>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QScreen>
#include <QStyleHints>
#include <QUrl>

#include "core/app_paths.h"
#include "core/application_model.h"
#include "core/database.h"
#include "core/exporter.h"
#include "core/records.h"

namespace {
AppController *s_instance = nullptr;

// 类型化的 QGuiApplication 取用（QCoreApplication::instance() 只给基类指针）
QGuiApplication *guiApp()
{
    return qobject_cast<QGuiApplication *>(QCoreApplication::instance());
}
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
    // 主题模式（M3）：不依赖数据库，最先建立（DB 打不开也要跟随系统深浅色）
    initDarkMode();

    m_db = std::make_unique<applycompass::Database>(applycompass::resolveDataDir());
    QString err;
    if (!m_db->open(&err)) {
        m_error = tr("无法打开数据库：%1").arg(err);
        m_db.reset();
        return;
    }
    m_model = new applycompass::ApplicationModel(m_db.get(), this);

    // 恢复缩放设置（Ctrl+滚轮）
    m_uiZoom = clampedZoom(m_db->setting(QStringLiteral("uiZoom"), QStringLiteral("1.0")).toDouble());

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

qreal AppController::clampedZoom(qreal value)
{
    // 对齐 10% 档位后 clamp 到 [70%, 160%]
    const qreal stepped = std::round(value * 10.0) / 10.0;
    return std::clamp(stepped, 0.7, 1.6);
}

// ---------------- 深色模式（M3） ----------------
// 来源优先级：环境强制（APPLYCOMPASS_FORCE_DARK/LIGHT，截图与测试的确定性入口）
//             ＞ setDarkModeOverride()（运行时测试）
//             ＞ 系统 QStyleHints.colorScheme（跟随，带变更信号）
void AppController::initDarkMode()
{
    if (qEnvironmentVariableIsSet("APPLYCOMPASS_FORCE_DARK"))
        m_darkModeOverride = 1;
    else if (qEnvironmentVariableIsSet("APPLYCOMPASS_FORCE_LIGHT"))
        m_darkModeOverride = 0;

    if (QGuiApplication *gui = guiApp()) {
        connect(gui->styleHints(), &QStyleHints::colorSchemeChanged, this,
                [this]() { recomputeDarkMode(); });
    }
    recomputeDarkMode();
}

bool AppController::darkMode() const
{
    return m_darkMode;
}

void AppController::setDarkModeOverride(int mode)
{
    const int m = std::clamp(mode, -1, 1);
    if (m == m_darkModeOverride)
        return;
    m_darkModeOverride = m;
    recomputeDarkMode();
}

void AppController::recomputeDarkMode()
{
    bool dark = false;
    if (m_darkModeOverride == 1) {
        dark = true;
    } else if (m_darkModeOverride == 0) {
        dark = false;
    } else if (QGuiApplication *gui = guiApp()) {
        dark = gui->styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    }
    const bool changed = dark != m_darkMode;
    m_darkMode = dark;
    applyDarkModePalette();
    if (changed)
        emit darkModeChanged();
}

void AppController::applyDarkModePalette()
{
    // 显式设置双调色板（而非依赖环境基线）：保证 FORCE 覆盖、跟随时切换两向
    // 都得到与控制令牌一致的外观（本机 KDE 暗色下环境调色板本身偏暗，不可依赖）。
    // 注：个别子树（如 Drawer 内的 QQC2 控件）在 KDE 平台主题下会解析到系统调色板，
    // 由 DetailsDrawer.qml 内容根上的显式 palette 角色固定（与下列色值一致）。
    if (QGuiApplication *gui = guiApp())
        gui->setPalette(m_darkMode ? darkPalette() : lightPalette());
}

// Fusion 控件浅色底座调色板（色值与 Theme.qml 浅色令牌对齐）
QPalette AppController::lightPalette()
{
    const QColor text(0x1D, 0x29, 0x39);
    const QColor border(0xD0, 0xD5, 0xDD);
    const QColor midlight(0xE4, 0xE7, 0xEC);
    const QColor disabled(0x98, 0xA2, 0xB3);
    const QColor highlight(0x25, 0x63, 0xEB);

    QPalette p;
    p.setColor(QPalette::Window, QColor(0xFF, 0xFF, 0xFF));
    p.setColor(QPalette::WindowText, text);
    p.setColor(QPalette::Base, QColor(0xFF, 0xFF, 0xFF));
    p.setColor(QPalette::AlternateBase, QColor(0xFA, 0xFB, 0xFC));
    p.setColor(QPalette::Text, text);
    p.setColor(QPalette::PlaceholderText, disabled);
    p.setColor(QPalette::Button, QColor(0xF2, 0xF4, 0xF7));
    p.setColor(QPalette::ButtonText, text);
    p.setColor(QPalette::BrightText, QColor(0xD9, 0x2D, 0x20));
    p.setColor(QPalette::Highlight, highlight);
    p.setColor(QPalette::HighlightedText, Qt::white);
    p.setColor(QPalette::ToolTipBase, QColor(0xFF, 0xFF, 0xFF));
    p.setColor(QPalette::ToolTipText, text);
    p.setColor(QPalette::Link, highlight);
    p.setColor(QPalette::Light, QColor(0xFF, 0xFF, 0xFF));
    p.setColor(QPalette::Midlight, midlight);
    p.setColor(QPalette::Mid, border);
    p.setColor(QPalette::Dark, disabled);
    p.setColor(QPalette::Shadow, border);
    p.setColor(QPalette::Disabled, QPalette::Text, disabled);
    p.setColor(QPalette::Disabled, QPalette::WindowText, disabled);
    p.setColor(QPalette::Disabled, QPalette::ButtonText, disabled);
    p.setColor(QPalette::Disabled, QPalette::HighlightedText, midlight);
    return p;
}

// Fusion 控件底座调色板（覆盖 ComboBox/Menu/TextField/滚动条等非自绘件），
// 色值与 Theme.qml 深色令牌对齐（灰蓝系）
QPalette AppController::darkPalette()
{
    const QColor window(0x1E, 0x22, 0x2A); // 面板
    const QColor base(0x16, 0x1A, 0x22);   // 输入底
    const QColor alt(0x1A, 0x1E, 0x27);
    const QColor text(0xE7, 0xEA, 0xF0);
    const QColor button(0x2A, 0x2F, 0x3A);
    const QColor disabled(0x6E, 0x77, 0x87);
    const QColor highlight(0x3B, 0x82, 0xF6);
    const QColor placeholder(0x8A, 0x93, 0xA3);

    QPalette p;
    p.setColor(QPalette::Window, window);
    p.setColor(QPalette::WindowText, text);
    p.setColor(QPalette::Base, base);
    p.setColor(QPalette::AlternateBase, alt);
    p.setColor(QPalette::Text, text);
    p.setColor(QPalette::PlaceholderText, placeholder);
    p.setColor(QPalette::Button, button);
    p.setColor(QPalette::ButtonText, text);
    p.setColor(QPalette::BrightText, QColor(0xFF, 0x6B, 0x6B));
    p.setColor(QPalette::Highlight, highlight);
    p.setColor(QPalette::HighlightedText, Qt::white);
    p.setColor(QPalette::ToolTipBase, button);
    p.setColor(QPalette::ToolTipText, text);
    p.setColor(QPalette::Link, highlight);
    p.setColor(QPalette::Light, QColor(0x4A, 0x52, 0x62));
    p.setColor(QPalette::Midlight, QColor(0x32, 0x39, 0x46));
    p.setColor(QPalette::Mid, QColor(0x3A, 0x41, 0x50));
    p.setColor(QPalette::Dark, QColor(0x20, 0x25, 0x2F));
    p.setColor(QPalette::Shadow, QColor(0x0D, 0x10, 0x15));
    p.setColor(QPalette::Disabled, QPalette::Text, disabled);
    p.setColor(QPalette::Disabled, QPalette::WindowText, disabled);
    p.setColor(QPalette::Disabled, QPalette::ButtonText, disabled);
    p.setColor(QPalette::Disabled, QPalette::HighlightedText, disabled);
    return p;
}

qreal AppController::uiZoom() const
{
    return m_uiZoom;
}

void AppController::setUiZoom(qreal value)
{
    const qreal v = clampedZoom(value);
    if (qFuzzyCompare(v, m_uiZoom))
        return;
    m_uiZoom = v;
    emit uiZoomChanged();
    if (m_db && m_db->isOpen())
        m_db->setSetting(QStringLiteral("uiZoom"), QString::number(v, 'f', 2));
}

void AppController::zoomBySteps(int steps)
{
    setUiZoom(m_uiZoom + steps * 0.1);
}

void AppController::zoomByWheelDeltas(int angleDeltaY, int pixelDeltaY)
{
    // 经典滚轮：一个刻度一步
    if (angleDeltaY != 0) {
        zoomBySteps(angleDeltaY > 0 ? 1 : -1);
        m_wheelPixelAccum = 0;
        return;
    }
    // 触摸板/平滑滚动（Wayland 常只有 pixelDelta）：累积 40px 一步
    if (pixelDeltaY == 0)
        return;
    m_wheelPixelAccum += pixelDeltaY;
    int steps = 0;
    while (m_wheelPixelAccum >= 40) {
        ++steps;
        m_wheelPixelAccum -= 40;
    }
    while (m_wheelPixelAccum <= -40) {
        --steps;
        m_wheelPixelAccum += 40;
    }
    if (steps != 0)
        zoomBySteps(steps);
}

QString AppController::lastExportMessage() const
{
    return m_lastExportMessage;
}

QVariantMap AppController::loadWindowState() const
{
    QVariantMap m;
    if (!m_db || !m_db->isOpen())
        return m;
    const QString wStr = m_db->setting(QStringLiteral("winWidth"), QString());
    if (wStr.isEmpty())
        return m; // 从未保存过 → 空 map（QML 保持默认）

    int x = m_db->setting(QStringLiteral("winX"), QStringLiteral("-1")).toInt();
    int y = m_db->setting(QStringLiteral("winY"), QStringLiteral("-1")).toInt();
    // 最小尺寸 clamp（与 Main.qml minimumWidth/minimumHeight 对齐）
    int w = qMax(wStr.toInt(), 980);
    int h = qMax(m_db->setting(QStringLiteral("winHeight"), QStringLiteral("820")).toInt(), 560);
    const bool maximized =
        m_db->setting(QStringLiteral("winMaximized"), QStringLiteral("0")) == QLatin1String("1");

    // 屏幕越界校验（防丢窗）：几何中心不落在任何屏幕可用区域内 → 丢弃位置，交给系统放置
    if (x >= 0 && y >= 0 && QGuiApplication::instance()) {
        const QPoint center(x + w / 2, y + h / 2);
        bool onScreen = false;
        const QList<QScreen *> screens = QGuiApplication::screens();
        for (QScreen *s : screens) {
            if (s->availableGeometry().contains(center)) {
                onScreen = true;
                break;
            }
        }
        if (!onScreen) {
            x = -1;
            y = -1;
        }
    }

    m.insert(QStringLiteral("x"), x);
    m.insert(QStringLiteral("y"), y);
    m.insert(QStringLiteral("width"), w);
    m.insert(QStringLiteral("height"), h);
    m.insert(QStringLiteral("maximized"), maximized);
    return m;
}

void AppController::saveWindowState(int x, int y, int width, int height, bool maximized)
{
    if (!m_db || !m_db->isOpen())
        return;
    m_db->setSetting(QStringLiteral("winX"), QString::number(x));
    m_db->setSetting(QStringLiteral("winY"), QString::number(y));
    m_db->setSetting(QStringLiteral("winWidth"), QString::number(width));
    m_db->setSetting(QStringLiteral("winHeight"), QString::number(height));
    m_db->setSetting(QStringLiteral("winMaximized"), maximized ? QStringLiteral("1")
                                                               : QStringLiteral("0"));
}

QVariantMap AppController::exportAll()
{
    QVariantMap res;
    if (!m_db) {
        m_lastExportMessage = tr("导出失败：数据库未打开");
        emit lastExportMessageChanged();
        res.insert(QStringLiteral("ok"), false);
        return res;
    }
    const applycompass::ExportResult r =
        applycompass::Exporter::exportAll(*m_db, applycompass::resolveExportDir());
    res.insert(QStringLiteral("ok"), r.ok());
    res.insert(QStringLiteral("xlsx"), r.xlsxPath);
    res.insert(QStringLiteral("csv"), r.csvPath);
    res.insert(QStringLiteral("error"), r.error);
    res.insert(QStringLiteral("warning"), r.warning);
    if (r.ok()) {
        m_lastExportMessage = r.warning.isEmpty()
                                  ? tr("已导出 → %1").arg(r.xlsxPath)
                                  : tr("已导出（%1）→ %2").arg(r.warning, r.xlsxPath);
    } else {
        m_lastExportMessage = tr("导出失败：%1").arg(r.error);
    }
    emit lastExportMessageChanged();
    return res;
}

void AppController::clearExportMessage()
{
    if (m_lastExportMessage.isEmpty())
        return;
    m_lastExportMessage.clear();
    emit lastExportMessageChanged();
}

bool AppController::openExportFolder() const
{
    return QDesktopServices::openUrl(QUrl::fromLocalFile(applycompass::resolveExportDir()));
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

void AppController::copyRows(int firstRow, int lastRow)
{
    if (!m_model)
        return;
    const QString tsv = m_model->tsvText(firstRow, lastRow);
    if (tsv.isEmpty())
        return;
    if (QGuiApplication *gui = guiApp())
        gui->clipboard()->setText(tsv);
}