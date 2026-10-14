cmake_minimum_required(VERSION 3.21)

project(ApplyCompass VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# QXlsx 的导出 CMake 目标引用 Qt6::GuiPrivate（Arch 打包如此）；
# Qt 6.11 默认不加载私有模块，需显式开启，否则 Generate 阶段报 target not found。
set(QT_FIND_PRIVATE_MODULES ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Sql Test QuickTest)
find_package(QXlsxQt6 REQUIRED)   # 旧表导入（pacman extra/qxlsx 1.5.1.1）

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)   # 为模块内子目录自动生成 qmldir（工具链友好）

# QML 模块统一输出到 build/qml/<模块名>，便于 qmllint/导入路径解析
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

# ---------------------------------------------------------------- 核心库（领域逻辑，无 UI）
add_library(applycompass_core STATIC
    src/core/records.h
    src/core/rule_engine.h
    src/core/rule_engine.cpp
    src/core/database.h
    src/core/database.cpp
    src/core/application_model.h
    src/core/application_model.cpp
    src/core/legacy_importer.h
    src/core/legacy_importer.cpp
    src/core/exporter.h
    src/core/exporter.cpp
    src/core/app_paths.h
    src/core/app_paths.cpp
)
target_include_directories(applycompass_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(applycompass_core
    PUBLIC Qt6::Core Qt6::Sql
    PRIVATE QXlsx::QXlsx
)
# 默认数据目录＝仓库 data/（可用 APPLYCOMPASS_DATA_DIR 环境变量覆盖）
# 默认导出目录＝../投递/导出（设计文档 §3.6；可用 APPLYCOMPASS_EXPORT_DIR 覆盖）
target_compile_definitions(applycompass_core PRIVATE
    APPLYCOMPASS_DEFAULT_DATA_DIR="${CMAKE_CURRENT_SOURCE_DIR}/data"
    APPLYCOMPASS_DEFAULT_EXPORT_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../投递/导出"
)
# ---------------------------------------------------------------- UI（QML 模块，静态库）
# 独立成库：应用与 QuickTest 测试二进制链接同一模块，避免资源路径问题。
add_library(applycompass_ui STATIC
    src/app_controller.h
    src/app_controller.cpp
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(applycompass_ui
    URI ApplyCompass
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/StatBar.qml
        qml/ApplicationTable.qml
        qml/RowDelegate.qml
        qml/StatusBlock.qml
        qml/RecordForm.qml
        qml/AddDialog.qml
        qml/DetailsDrawer.qml
        qml/AppButton.qml
        qml/ZoomWheelHandler.qml
)

target_link_libraries(applycompass_ui
    PUBLIC Qt6::Quick Qt6::QuickControls2 applycompass_core
    PRIVATE Qt6::Gui
)
target_include_directories(applycompass_ui PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

# ---------------------------------------------------------------- 应用
qt_add_executable(appApplyCompass
    src/main.cpp
)
target_link_libraries(appApplyCompass PRIVATE applycompass_ui)

# ---------------------------------------------------------------- 测试
enable_testing()
add_subdirectory(tests)
