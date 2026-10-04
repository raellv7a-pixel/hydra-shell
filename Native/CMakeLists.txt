cmake_minimum_required(VERSION 3.21)
project(HydraInput LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
qt_add_qml_module(hydrainput URI qs.Native.Input VERSION 1.0
  OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/Input"
  SOURCES KeyboardState.h KeyboardState.cpp)
target_link_libraries(hydrainput PRIVATE Qt6::Gui PkgConfig::WAYLAND)
# Quickshell resolves source imports through qs:@ URLs, which cannot be used
# by dlopen. The generated descriptor points at the real build location.
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/install-qmldir.cmake" CONTENT
  "file(WRITE \"${CMAKE_CURRENT_SOURCE_DIR}/Input/qmldir\" \"module qs.Native.Input\\nplugin hydrainputplugin ${CMAKE_CURRENT_SOURCE_DIR}/Input\\ntypeinfo hydrainput.qmltypes\\n\")")
add_custom_target(hydrainput_descriptor ALL
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_BINARY_DIR}/install-qmldir.cmake"
  DEPENDS hydrainputplugin)
