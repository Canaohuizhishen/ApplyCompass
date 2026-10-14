# 测试目标（QTest 单测 + QuickTest 交互测试）
qt_add_executable(tst_rule_engine tst_rule_engine.cpp)
target_link_libraries(tst_rule_engine PRIVATE applycompass_core Qt6::Test)
add_test(NAME tst_rule_engine COMMAND tst_rule_engine)

qt_add_executable(tst_database tst_database.cpp)
target_link_libraries(tst_database PRIVATE applycompass_core Qt6::Test)
add_test(NAME tst_database COMMAND tst_database)

qt_add_executable(tst_importer tst_importer.cpp)
target_link_libraries(tst_importer PRIVATE applycompass_core Qt6::Test)
target_compile_definitions(tst_importer PRIVATE
    APPLYCOMPASS_LEGACY_XLSM="${CMAKE_CURRENT_SOURCE_DIR}/../../投递/我的投递记录_宏版.xlsm")
add_test(NAME tst_importer COMMAND tst_importer)

qt_add_executable(tst_model tst_model.cpp)
target_link_libraries(tst_model PRIVATE applycompass_core Qt6::Test)
add_test(NAME tst_model COMMAND tst_model)

qt_add_executable(tst_export tst_export.cpp)
target_link_libraries(tst_export PRIVATE applycompass_core Qt6::Test QXlsx::QXlsx)
add_test(NAME tst_export COMMAND tst_export)

# AppController 启动逻辑（主题偏好持久化时序；需 QGuiApplication → offscreen）
qt_add_executable(tst_controller tst_controller.cpp)
target_link_libraries(tst_controller PRIVATE applycompass_ui Qt6::Test)
add_test(NAME tst_controller COMMAND tst_controller)
set_tests_properties(tst_controller PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

# QuickTest（qmltestrunner 等价）：UI 场景 1–6 交互链路
qt_add_executable(tst_ui quicktest_main.cpp)
target_link_libraries(tst_ui PRIVATE applycompass_ui Qt6::Test Qt6::QuickTest)
add_test(NAME tst_ui COMMAND tst_ui -input ${CMAKE_CURRENT_SOURCE_DIR}/qml)
set_tests_properties(tst_ui PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
