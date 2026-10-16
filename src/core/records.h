#pragma once

#include <QDate>
#include <QString>
#include <QStringList>

namespace applycompass {

// ---- 枚举取值 ----
// 状态/渠道与旧表实测下拉一致（openpyxl 取数据验证）：状态 9 项、渠道 9 项；
// 简历版本随现行 PDF 演进为 4 项（客户端 / 服务端 / 全栈 / 通用版）。
// 状态顺序即设计文档 §3.7 数字键 1–9 的下拉序。
namespace enums {

inline const QStringList Statuses = {
    QStringLiteral("初筛"), QStringLiteral("笔试"), QStringLiteral("面试"),
    QStringLiteral("Offer"),
    QStringLiteral("简历挂"), QStringLiteral("笔试挂"), QStringLiteral("面试挂"),
    QStringLiteral("挂"), QStringLiteral("放弃"),
};
inline const QStringList Channels = {
    QStringLiteral("官网"), QStringLiteral("邮箱"), QStringLiteral("公众号"),
    QStringLiteral("双选会"), QStringLiteral("BOSS"), QStringLiteral("智联"),
    QStringLiteral("牛客"), QStringLiteral("应届生"), QStringLiteral("其他"),
};
inline const QStringList ResumeVersions = {
    QStringLiteral("C++Qt客户端开发"),
    QStringLiteral("C++服务端开发"),
    QStringLiteral("C++全栈开发"),
    QStringLiteral("通用版"),
};
inline const QStringList Kinds = {QStringLiteral("实习"), QStringLiteral("正式")};

inline const QString Offer = QStringLiteral("Offer");
inline const QStringList InProgressStatuses = {
    QStringLiteral("初筛"), QStringLiteral("笔试"), QStringLiteral("面试")};
inline const QStringList RejectedStatuses = {
    QStringLiteral("简历挂"), QStringLiteral("笔试挂"), QStringLiteral("面试挂"),
    QStringLiteral("挂")};

} // namespace enums

// 一条投递记录。status 为空 = 待投区；非空 = 已投区（设计文档 §3.1）。
struct ApplicationRecord
{
    qint64 id = -1;
    QString company;       // 公司（必填）
    QString position;      // 岗位名称（必填）
    QString kind;          // 实习 / 正式
    QString region;        // 地区
    QDate applyDate;       // 投递日期（可空；填状态时自动补今天）
    QString channel;       // 渠道
    QString status;        // 状态（空 = 待投）
    QDate statusUpdated;   // 状态更新（自动 = 状态变更当日）
    QString resumeVersion; // 简历版本
    QString link;          // 跟进链接
    QString duties;        // 职责（多行）
    QString requirements;  // 要求（多行）
    QString notes;         // 备注（多行）
    QString salary;        // 薪资（仅 Offer 时展示；数据始终保留）
    qint64 sortIndex = 0;  // 区内顺序（全局递增；填状态取 max+1 入已投区尾，清空保留）
    QString createdAt;     // ISO 8601
    QString updatedAt;     // ISO 8601

    bool isApplied() const { return !status.isEmpty(); }
};

// 状态时间线事件（只读展示；from/to 为空表示空状态）。
struct StatusEvent
{
    qint64 id = -1;
    qint64 applicationId = -1;
    QString fromStatus;
    QString toStatus;
    QString at; // ISO 8601 datetime
};

} // namespace applycompass
