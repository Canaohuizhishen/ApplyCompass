#pragma once

#include <QObject>
#include <QPalette>
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
    Q_PROPERTY(qreal uiZoom READ uiZoom NOTIFY uiZoomChanged)
    Q_PROPERTY(QString lastExportMessage READ lastExportMessage NOTIFY lastExportMessageChanged)
    Q_PROPERTY(bool darkMode READ darkMode NOTIFY darkModeChanged)

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

    // ---- 缩放（Ctrl+滚轮，Excel 式）----
    qreal uiZoom() const;
    Q_INVOKABLE void setUiZoom(qreal value); // 自动 clamp 到 [0.7, 1.6] 并持久化（10% 对齐）
    Q_INVOKABLE void zoomBySteps(int steps); // 每步 ±10%
    // 滚轮增量入口：经典滚轮用 angleDelta；Wayland 触摸板/平滑滚动只有 pixelDelta，
    // 以 40px 为一步累积（防过灵敏）。见 qml/ZoomWheelHandler.qml。
    Q_INVOKABLE void zoomByWheelDeltas(int angleDeltaY, int pixelDeltaY);

    // ---- 深色模式（M3）：跟随系统 + 环境强制覆盖 ----
    bool darkMode() const;
    // -1=跟随系统；0=强制浅色；1=强制深色（会话级；测试与截图用，见 APPLYCOMPASS_FORCE_DARK/LIGHT）
    Q_INVOKABLE void setDarkModeOverride(int mode);

    // ---- 窗口布局记忆（M3，§10）：大小/最大化可靠；位置 Wayland 下尽力而为 ----
    // 返回 {x,y,width,height,maximized}；从未保存过 → 空 map。含屏幕越界校验（防丢窗）。
    Q_INVOKABLE QVariantMap loadWindowState() const;
    Q_INVOKABLE void saveWindowState(int x, int y, int width, int height, bool maximized);
    // ---- 导出（§3.6）----
    QString lastExportMessage() const;
    Q_INVOKABLE QVariantMap exportAll();      // 全量导出 xlsx+csv，返回 {ok,xlsx,csv,error,warning}
    Q_INVOKABLE void clearExportMessage();
    Q_INVOKABLE bool openExportFolder() const;

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
    Q_INVOKABLE void copyRows(int firstRow, int lastRow);   // Ctrl+C：选中行区间 → TSV 剪贴板（M3）

signals:
    void errorMessageChanged();
    void uiZoomChanged();
    void lastExportMessageChanged();
    void darkModeChanged();

private:
    void initialize();

    static qreal clampedZoom(qreal value);

    void initDarkMode();        // 环境覆盖 + 系统 colorScheme 跟随
    void recomputeDarkMode();   // 依当前来源计算 darkMode 并联动 QPalette
    void applyDarkModePalette();
    static QPalette darkPalette();
    static QPalette lightPalette();

    std::unique_ptr<applycompass::Database> m_db;
    applycompass::ApplicationModel *m_model = nullptr;
    QString m_error;
    qreal m_uiZoom = 1.0;
    int m_wheelPixelAccum = 0; // 触摸板像素级滚动的累积量（±40px = 一步）
    QString m_lastExportMessage;

    int m_darkModeOverride = -1; // -1=跟随系统；0/1=环境或调用方强制
    bool m_darkMode = false;
};
