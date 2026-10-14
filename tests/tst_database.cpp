#include <QtTest>

#include <QTemporaryDir>
#include <memory>

#include "core/database.h"

using namespace applycompass;

// 存储层单测：CRUD、双段排序、时间线级联、备份轮转、重启持久化（场景 11 数据内核）。
class TstDatabase : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    void crudRoundTrip();
    void sectionOrdering();
    void statusEventsCascade();
    void deleteAllRecords();
    void backupsAndRotation();
    void persistenceAcrossReopen();

private:
    std::unique_ptr<QTemporaryDir> m_tmp;
    std::unique_ptr<Database> m_db;
};

void TstDatabase::init()
{
    m_tmp = std::make_unique<QTemporaryDir>();
    QVERIFY(m_tmp->isValid());
    m_db = std::make_unique<Database>(m_tmp->path());
    QString err;
    QVERIFY2(m_db->open(&err), qPrintable(err));
}

void TstDatabase::cleanup()
{
    m_db.reset();
    m_tmp.reset();
}

void TstDatabase::crudRoundTrip()
{
    ApplicationRecord rec;
    rec.company = QStringLiteral("某某科技");
    rec.position = QStringLiteral("后端开发实习生");
    rec.kind = QStringLiteral("实习");
    rec.region = QStringLiteral("成都");
    rec.applyDate = QDate(2026, 10, 14);
    rec.channel = QStringLiteral("BOSS");
    rec.status = QStringLiteral("初筛");
    rec.statusUpdated = QDate(2026, 10, 14);
    rec.resumeVersion = QStringLiteral("C++服务端开发");
    rec.link = QStringLiteral("https://example.com/job/1");
    rec.duties = QStringLiteral("职责一\n职责二\n职责三");
    rec.requirements = QStringLiteral("要求一\n要求二");
    rec.notes = QStringLiteral("多行\n备注");
    rec.salary = QStringLiteral("25w");
    rec.sortIndex = 1;

    const qint64 id = m_db->insertRecord(rec);
    QVERIFY(id > 0);
    QVERIFY(!rec.createdAt.isEmpty());
    QCOMPARE(m_db->recordCount(), qint64(1));

    QVector<ApplicationRecord> all = m_db->loadAll();
    QCOMPARE(all.size(), 1);
    const ApplicationRecord &got = all.at(0);
    QCOMPARE(got.company, rec.company);
    QCOMPARE(got.position, rec.position);
    QCOMPARE(got.kind, rec.kind);
    QCOMPARE(got.region, rec.region);
    QCOMPARE(got.applyDate, rec.applyDate);
    QCOMPARE(got.channel, rec.channel);
    QCOMPARE(got.status, rec.status);
    QCOMPARE(got.statusUpdated, rec.statusUpdated);
    QCOMPARE(got.resumeVersion, rec.resumeVersion);
    QCOMPARE(got.link, rec.link);
    QCOMPARE(got.duties, rec.duties);
    QCOMPARE(got.requirements, rec.requirements);
    QCOMPARE(got.notes, rec.notes);
    QCOMPARE(got.salary, rec.salary);
    QCOMPARE(got.sortIndex, rec.sortIndex);

    ApplicationRecord edited = got;
    edited.company = QStringLiteral("改名公司");
    edited.notes.clear();
    edited.applyDate = QDate(); // 清空日期 → NULL
    QVERIFY(m_db->updateRecord(edited));

    all = m_db->loadAll();
    QCOMPARE(all.at(0).company, QStringLiteral("改名公司"));
    QVERIFY(all.at(0).notes.isEmpty());
    QVERIFY(all.at(0).applyDate.isNull());

    QVERIFY(m_db->removeRecord(id));
    QCOMPARE(m_db->recordCount(), qint64(0));
}

void TstDatabase::sectionOrdering()
{
    auto insert = [this](const QString &company, const QString &status, qint64 sort) {
        ApplicationRecord r;
        r.company = company;
        r.position = QStringLiteral("岗位");
        r.status = status;
        r.sortIndex = sort;
        return m_db->insertRecord(r);
    };

    insert(QStringLiteral("已投A"), QStringLiteral("初筛"), 5);
    insert(QStringLiteral("待投B"), QString(), 1);
    insert(QStringLiteral("待投C"), QString(), 2);
    insert(QStringLiteral("已投D"), QStringLiteral("Offer"), 6);

    const QVector<ApplicationRecord> all = m_db->loadAll();
    QCOMPARE(all.size(), 4);
    QCOMPARE(all.at(0).company, QStringLiteral("已投A")); // 已投区按 sort_index
    QCOMPARE(all.at(1).company, QStringLiteral("已投D"));
    QCOMPARE(all.at(2).company, QStringLiteral("待投B")); // 待投区按 sort_index
    QCOMPARE(all.at(3).company, QStringLiteral("待投C"));
    QCOMPARE(m_db->maxSortIndex(), qint64(6));
}

void TstDatabase::statusEventsCascade()
{
    ApplicationRecord r;
    r.company = QStringLiteral("事件公司");
    r.position = QStringLiteral("岗位");
    const qint64 id = m_db->insertRecord(r);
    QVERIFY(id > 0);

    QVERIFY(m_db->addStatusEvent(id, QString(), QStringLiteral("初筛")));
    QVERIFY(m_db->addStatusEvent(id, QStringLiteral("初筛"), QStringLiteral("笔试")));

    QVector<StatusEvent> events = m_db->statusEvents(id);
    QCOMPARE(events.size(), 2);
    QVERIFY(events.at(0).fromStatus.isEmpty());
    QCOMPARE(events.at(0).toStatus, QStringLiteral("初筛"));
    QCOMPARE(events.at(1).fromStatus, QStringLiteral("初筛"));
    QCOMPARE(events.at(1).toStatus, QStringLiteral("笔试"));
    QVERIFY(!events.at(0).at.isEmpty());

    QVERIFY(m_db->removeRecord(id)); // 级联删除时间线
    QCOMPARE(m_db->statusEvents(id).size(), 0);
}

void TstDatabase::deleteAllRecords()
{
    ApplicationRecord r;
    r.company = QStringLiteral("甲");
    r.position = QStringLiteral("岗");
    const qint64 id = m_db->insertRecord(r);
    QVERIFY(m_db->addStatusEvent(id, QString(), QStringLiteral("初筛")));
    r.company = QStringLiteral("乙");
    QVERIFY(m_db->insertRecord(r) > 0);

    QVERIFY(m_db->deleteAllRecords());
    QCOMPARE(m_db->recordCount(), qint64(0));
    QCOMPARE(m_db->statusEvents(id).size(), 0);
}

void TstDatabase::backupsAndRotation()
{
    ApplicationRecord r;
    r.company = QStringLiteral("备份公司");
    r.position = QStringLiteral("岗位");
    QVERIFY(m_db->insertRecord(r) > 0);

    const QString backup = m_db->backupNow();
    QVERIFY(!backup.isEmpty());
    QVERIFY(QFile::exists(backup));
    QVERIFY(backup.contains(QStringLiteral("/backups/")));
    QVERIFY(m_db->hasBackupToday());

    // 假造 18 份历史备份（2026-09-01 ~ 09-18），共 19 份 → 轮转留 14
    QDir dir(m_db->backupsDir());
    for (int day = 1; day <= 18; ++day) {
        const QString name = QStringLiteral("applycompass_2026-09-%1_120000.db")
                                 .arg(day, 2, 10, QLatin1Char('0'));
        QFile f(dir.filePath(name));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("x");
        f.close();
    }
    QCOMPARE(m_db->backupFiles().size(), 19);
    QCOMPARE(m_db->rotateBackups(14), 5);
    const QList<QString> left = m_db->backupFiles();
    QCOMPARE(left.size(), 14);
    QVERIFY(left.first().endsWith(QStringLiteral(".db")));
    QVERIFY(left.first() != left.last());
    QVERIFY(QFile::exists(backup)); // 最新一份必须还在
    QVERIFY(!QFile::exists(dir.filePath(QStringLiteral("applycompass_2026-09-01_120000.db"))));
    QVERIFY(QFile::exists(dir.filePath(QStringLiteral("applycompass_2026-09-06_120000.db"))));

    // 再轮转一次：已 ≤14 份 → 不删
    QCOMPARE(m_db->rotateBackups(14), 0);
}

void TstDatabase::persistenceAcrossReopen()
{
    ApplicationRecord r;
    r.company = QStringLiteral("持久公司");
    r.position = QStringLiteral("持久岗位");
    r.status = QStringLiteral("初筛");
    r.applyDate = QDate(2026, 10, 14);
    r.statusUpdated = QDate(2026, 10, 14);
    const qint64 id = m_db->insertRecord(r);
    QVERIFY(id > 0);
    QVERIFY(m_db->addStatusEvent(id, QString(), QStringLiteral("初筛")));

    m_db.reset(); // 关闭连接（模拟应用退出）

    QString err;
    auto reopened = std::make_unique<Database>(m_tmp->path());
    QVERIFY2(reopened->open(&err), qPrintable(err));
    QCOMPARE(reopened->recordCount(), qint64(1));
    const QVector<ApplicationRecord> all = reopened->loadAll();
    QCOMPARE(all.size(), 1);
    QCOMPARE(all.at(0).company, QStringLiteral("持久公司"));
    QCOMPARE(all.at(0).status, QStringLiteral("初筛"));
    QCOMPARE(all.at(0).applyDate, QDate(2026, 10, 14));
    QCOMPARE(reopened->statusEvents(id).size(), 1); // 时间线同步持久化
}

QTEST_GUILESS_MAIN(TstDatabase)

#include "tst_database.moc"
