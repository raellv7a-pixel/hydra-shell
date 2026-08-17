# Caelestia Blob port — GPLv3 attribution and scope

Hydra Shell incorporates and modifies the Blob rendering subsystem from [Caelestia Shell](https://github.com/caelestia-dots/shell), which is distributed under the GNU General Public License version 3.

Source reference used for the port:

- Repository: `https://github.com/caelestia-dots/shell`
- Local reference checkout: `/home/raell/Projetos/Exemplos/Caelestia`
- License: GPL-3.0-only; see the root `LICENSE` file.
- Upstream subsystem: `plugin/src/Caelestia/Blobs/`

The imported and modified source inventory is:

- `blobgroup.cpp`, `blobgroup.hpp`
- `blobshape.cpp`, `blobshape.hpp`
- `blobrect.cpp`, `blobrect.hpp`
- `blobinvertedrect.cpp`, `blobinvertedrect.hpp`
- `blobmaterial.cpp`, `blobmaterial.hpp`
- `shaders/blob.frag`, `shaders/blob.vert`
- the minimal CMake/QML module definition required to build those sources

Hydra-specific modifications currently include the QML module rename from `Caelestia.Blobs` to `Hydra.Visual`, a standalone CMake build, and explicit SPDX attribution on every imported source. Integration with Hydra `MainScreen`/`SmartPanel`, CachyOS/Nix installation and performance-mode controls are tracked separately. Modified source files retain upstream attribution and record that they were modified for Hydra Shell.

No Caelestia branding or nonessential assets are included by this decision. Other Caelestia components or third-party dependencies, including `M3Shapes`, require a separate license audit before incorporation.

The combined Hydra Shell work is distributed under GPL-3.0-only. Code inherited from Noctalia remains available under its original MIT terms as recorded in `Noctalia-MIT.txt`; the combined distribution is governed by GPLv3.
