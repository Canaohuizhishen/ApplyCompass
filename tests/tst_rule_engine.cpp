#include <QtTest>

#include "core/rule_engine.h"

using namespace applycompass;

// 规则引擎纯逻辑单测（设计文档 §5；场景 2/3/4/5 的内核）。
class TstRuleEngine : public QObject
{
    Q_OBJECT

private slots:
    void fillStatusFromEmpty();        // 填状态：空→初筛 → 双日期 + 入已投区尾
    void changeStatus();               // 改状态：仅 状态更新=今天
    void clearStatus();                // 清空：退回待投区、日期与顺序保留
    void noChangeIsNoOp();             // 同值/空→空：不动
    void fillKeepsExistingApplyDate(); // 已有投递日期不被覆盖
    void fillClearRefillRoundTrip();   // 填→清→再填 的 sortIndex 语义
};

void TstRuleEngine::fillStatusFromEmpty()
{
    ApplicationRecord rec;
    const QDate today(2026, 10, 14);

    const auto t = RuleEngine::applyStatusChange(rec, QStringLiteral("初筛"), today, 100);

    QVERIFY(t.statusChanged);
    QVERIFY(t.applyDateSet);
    QVERIFY(t.statusUpdatedSet);
    QCOMPARE(t.move, RuleEngine::Transition::ToApplied);
    QCOMPARE(rec.status, QStringLiteral("初筛"));
    QCOMPARE(rec.applyDate, today);
    QCOMPARE(rec.statusUpdated, today);
    QCOMPARE(rec.sortIndex, qint64(100));
}

void TstRuleEngine::changeStatus()
{
    ApplicationRecord rec;
    rec.status = QStringLiteral("初筛");
    rec.applyDate = QDate(2026, 10, 1);
    rec.statusUpdated = QDate(2026, 10, 1);
    rec.sortIndex = 7;
    const QDate today(2026, 10, 14);

    const auto t = RuleEngine::applyStatusChange(rec, QStringLiteral("笔试"), today, 999);

    QVERIFY(t.statusChanged);
    QVERIFY(!t.applyDateSet);
    QVERIFY(t.statusUpdatedSet);
    QCOMPARE(t.move, RuleEngine::Transition::None);
    QCOMPARE(rec.status, QStringLiteral("笔试"));
    QCOMPARE(rec.applyDate, QDate(2026, 10, 1));    // 投递日期不动
    QCOMPARE(rec.statusUpdated, today);             // 仅状态更新
    QCOMPARE(rec.sortIndex, qint64(7));             // 区内顺序不动
}

void TstRuleEngine::clearStatus()
{
    ApplicationRecord rec;
    rec.status = QStringLiteral("面试");
    rec.applyDate = QDate(2026, 10, 1);
    rec.statusUpdated = QDate(2026, 10, 5);
    rec.sortIndex = 7;

    const auto t = RuleEngine::applyStatusChange(rec, QString(), QDate(2026, 10, 14), 999);

    QVERIFY(t.statusChanged);
    QCOMPARE(t.move, RuleEngine::Transition::ToPending);
    QVERIFY(rec.status.isEmpty());
    QCOMPARE(rec.applyDate, QDate(2026, 10, 1));    // 日期保留
    QCOMPARE(rec.statusUpdated, QDate(2026, 10, 5)); // 日期保留
    QCOMPARE(rec.sortIndex, qint64(7));             // 保留 → 退回待投区原位
}

void TstRuleEngine::noChangeIsNoOp()
{
    const QDate today(2026, 10, 14);

    ApplicationRecord rec;
    rec.status = QStringLiteral("初筛");
    rec.statusUpdated = QDate(2026, 10, 1);
    const auto t1 = RuleEngine::applyStatusChange(rec, QStringLiteral("初筛"), today, 999);
    QVERIFY(!t1.statusChanged);
    QCOMPARE(rec.statusUpdated, QDate(2026, 10, 1)); // 同值不改状态更新

    ApplicationRecord empty;
    const auto t2 = RuleEngine::applyStatusChange(empty, QString(), today, 999);
    QVERIFY(!t2.statusChanged);
    QCOMPARE(t2.move, RuleEngine::Transition::None);
    QVERIFY(empty.applyDate.isNull());
    QVERIFY(empty.statusUpdated.isNull());
}

void TstRuleEngine::fillKeepsExistingApplyDate()
{
    ApplicationRecord rec;
    rec.applyDate = QDate(2026, 9, 1); // 手改过投递日期
    const QDate today(2026, 10, 14);

    const auto t = RuleEngine::applyStatusChange(rec, QStringLiteral("Offer"), today, 5);

    QVERIFY(t.statusChanged);
    QVERIFY(!t.applyDateSet);
    QCOMPARE(rec.applyDate, QDate(2026, 9, 1));
    QCOMPARE(rec.statusUpdated, today);
    QCOMPARE(t.move, RuleEngine::Transition::ToApplied);
}

void TstRuleEngine::fillClearRefillRoundTrip()
{
    ApplicationRecord rec;
    const QDate today(2026, 10, 14);

    RuleEngine::applyStatusChange(rec, QStringLiteral("初筛"), today, 10);
    QCOMPARE(rec.sortIndex, qint64(10));
    const QDate firstApply = rec.applyDate;

    RuleEngine::applyStatusChange(rec, QString(), today, 20);
    QVERIFY(rec.status.isEmpty());
    QCOMPARE(rec.sortIndex, qint64(10)); // 清空不接新序号
    QCOMPARE(rec.applyDate, firstApply);

    const auto t = RuleEngine::applyStatusChange(rec, QStringLiteral("笔试"), today, 21);
    QCOMPARE(t.move, RuleEngine::Transition::ToApplied);
    QCOMPARE(rec.sortIndex, qint64(21)); // 再填：入已投区尾
    QCOMPARE(rec.applyDate, firstApply); // 已有日期仍保留
}

QTEST_GUILESS_MAIN(TstRuleEngine)

#include "tst_rule_engine.moc"
