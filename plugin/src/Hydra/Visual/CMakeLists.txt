# SPDX-FileCopyrightText: 2026 Mvk <53517019+Mvkweb@users.noreply.github.com>
# SPDX-License-Identifier: GPL-3.0-only
# Modified for Hydra Shell in 2026.

qt_add_qml_module(hydra_visual
    URI Hydra.Visual
    VERSION 1.0
    SOURCES
        blobgroup.cpp
        blobgroup.hpp
        blobshape.cpp
        blobshape.hpp
        blobrect.cpp
        blobrect.hpp
        blobinvertedrect.cpp
        blobinvertedrect.hpp
        blobmaterial.cpp
        blobmaterial.hpp
)

target_link_libraries(hydra_visual
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
)

qt_add_shaders(hydra_visual "hydra_visual_blob_shaders"
    BATCHABLE
    OPTIMIZED
    NOHLSL
    NOMSL
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/blob.frag
        shaders/blob.vert
)
