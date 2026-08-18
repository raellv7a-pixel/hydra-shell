# SPDX-License-Identifier: GPL-3.0-only

cmake_minimum_required(VERSION 3.21)

project(HydraVisual VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Qml Quick ShaderTools)

include(GNUInstallDirs)

qt_standard_project_setup(REQUIRES 6.9)
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

add_subdirectory(src/Hydra/Visual)

# ── M3Shapes — Apache-2.0, audited and cleared for GPL-3.0-only combined
# distribution; see LICENSES/M3Shapes-Attribution.md. Vendored unmodified via
# FetchContent at the pinned revision below; not copied into this repo. Nix
# builds pass FETCHCONTENT_SOURCE_DIR_M3SHAPES_EXTERNAL (see nix/package.nix)
# to reuse the flake-fetched source instead of a sandboxed network clone.
option(HYDRA_ENABLE_M3SHAPES "Fetch and build the M3Shapes QML module" ON)

if(HYDRA_ENABLE_M3SHAPES)
    include(FetchContent)
    set(M3SHAPES_REV bdc327b29f95394a732baf3c9b19658ba23755b6)
    set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "QML install dir")
    FetchContent_Declare(
        m3shapes_external
        GIT_REPOSITORY https://github.com/soramanew/m3shapes.git
        GIT_TAG        ${M3SHAPES_REV}
        SOURCE_DIR     "${CMAKE_BINARY_DIR}/_deps/m3shapes-${M3SHAPES_REV}"
    )
    FetchContent_MakeAvailable(m3shapes_external)

    if(TARGET m3shapesplugin)
        set_target_properties(m3shapesplugin PROPERTIES INSTALL_RPATH "$ORIGIN")
    endif()
endif()
