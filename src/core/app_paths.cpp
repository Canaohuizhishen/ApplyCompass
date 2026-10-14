#include "core/app_paths.h"

#include <QDir>

namespace applycompass {

QString resolveDataDir()
{
    const QString env = qEnvironmentVariable("APPLYCOMPASS_DATA_DIR");
    if (!env.isEmpty())
        return QDir(env).absolutePath();
#ifdef APPLYCOMPASS_DEFAULT_DATA_DIR
    return QStringLiteral(APPLYCOMPASS_DEFAULT_DATA_DIR);
#else
    return QDir::current().filePath(QStringLiteral("data"));
#endif
}

QString resolveExportDir()
{
    const QString env = qEnvironmentVariable("APPLYCOMPASS_EXPORT_DIR");
    if (!env.isEmpty())
        return QDir(env).absolutePath();
#ifdef APPLYCOMPASS_DEFAULT_EXPORT_DIR
    return QStringLiteral(APPLYCOMPASS_DEFAULT_EXPORT_DIR);
#else
    return QDir(resolveDataDir()).filePath(QStringLiteral("导出"));
#endif
}

} // namespace applycompass
