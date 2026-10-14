#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include <cstdio>

#include "core/app_paths.h"
#include "core/database.h"
#include "core/legacy_importer.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("投递罗盘"));
    app.setOrganizationName(QStringLiteral("ApplyCompass"));
    app.setApplicationVersion(QStringLiteral("0.1.0"));

    // 锁定 Fusion 样式：本机 KDE Breeze QQC2 样式与 Qt 6.11 存在不兼容
    //（TextArea 的 MobileTextActionsToolBar 目标类型不匹配），Fusion 在各环境行为一致。
    // 深浅色打磨（M3）时再评估是否切回系统样式。
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("投递罗盘 · ApplyCompass"));
    parser.addHelpOption();
    QCommandLineOption dataDirOption(
        QStringLiteral("data-dir"),
        QStringLiteral("数据目录（默认：仓库 data/；可用环境变量 APPLYCOMPASS_DATA_DIR 覆盖）"),
        QStringLiteral("dir"));
    QCommandLineOption importOption(
        QStringLiteral("import-legacy"),
        QStringLiteral("一次性导入旧表 .xlsm（跳过【宏测试行】；要求库为空）"),
        QStringLiteral("xlsm"));
    parser.addOptions({dataDirOption, importOption});
    parser.process(app);

    if (parser.isSet(dataDirOption))
        qputenv("APPLYCOMPASS_DATA_DIR", parser.value(dataDirOption).toLocal8Bit());

    // ---- 一次性导入模式（不开 GUI）----
    if (parser.isSet(importOption)) {
        const QString dataDir = applycompass::resolveDataDir();
        applycompass::Database db(dataDir);
        QString err;
        if (!db.open(&err)) {
            std::fprintf(stderr, "错误：%s\n", qUtf8Printable(err));
            return 2;
        }
        if (db.recordCount() > 0) {
            std::fprintf(stderr,
                         "错误：数据库已有 %lld 条记录，拒绝重复导入。\n"
                         "  数据库：%s\n"
                         "  如需重新导入，请先移除该文件（或用 --data-dir 指向新目录）。\n",
                         static_cast<long long>(db.recordCount()),
                         qUtf8Printable(db.dbPath()));
            return 3;
        }
        const applycompass::ImportSummary summary =
            applycompass::LegacyImporter::importFromXlsm(parser.value(importOption), db);
        if (!summary.error.isEmpty()) {
            std::fprintf(stderr, "错误：%s\n", qUtf8Printable(summary.error));
            return 4;
        }
        std::printf("导入完成：%d 条（跳过 %d 行）。\n  数据目录：%s\n",
                    summary.imported, summary.skipped, qUtf8Printable(dataDir));
        return 0;
    }

    // ---- GUI 模式 ----
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("ApplyCompass", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
