# M3Shapes — license audit and integration scope

## Audit result: cleared for incorporation

- Repository: `https://github.com/soramanew/m3shapes`
- License: **Apache License 2.0** (full text mirrored in [`M3Shapes-Apache-2.0.txt`](./M3Shapes-Apache-2.0.txt); verified against the upstream `LICENSE` file, no separate `NOTICE` file exists in the repository).
- Nature: a Qt6/QML C++ plugin (`import M3Shapes`) that ports Android's `androidx.graphics.shapes` (also Apache-2.0) to Qt — a Material 3 shape catalog (34 shapes: `Circle`, `Heart`, `Cookie9Sided`, …) with GPU-accelerated smooth-shape rendering and morph-tween animation between shapes.
- Compatibility: Apache License 2.0 is explicitly one-way compatible with GPL-3.0 per the [FSF's license list](https://www.gnu.org/licenses/license-list.en.html#apache2) — Apache-2.0 code may be combined into a GPLv3 work; the combined distribution is governed by GPLv3, while the Apache-2.0 portions retain their original license and notices in their own source files.

**Conclusion: M3Shapes may be incorporated into Hydra Shell.** This closes the item flagged in [`Caelestia-Blob-Port.md`](./Caelestia-Blob-Port.md#L24).

## Integration approach

M3Shapes is **vendored unmodified** as a build-time dependency, the same pattern Caelestia Shell itself uses (`caelestia-dots/shell`'s root `CMakeLists.txt` `FetchContent_Declare(m3shapes_external ...)`), not copied or hand-ported into this repository:

- `plugin/CMakeLists.txt` fetches the pinned upstream revision `bdc327b29f95394a732baf3c9b19658ba23755b6` via CMake `FetchContent` and builds it as a sibling QML module alongside `Hydra.Visual`, installed to `<prefix>/lib/qt6/qml/M3Shapes/`.
- No Hydra source files are added under an `M3Shapes` namespace and no upstream file is edited — the Apache-2.0 copyright/license headers embedded in the upstream sources are therefore preserved verbatim, satisfying License §4(b)/(c).
- `Scripts/dev/build-visual-plugin.sh` (unchanged) already builds the whole `plugin/` tree, so it picks up M3Shapes automatically.
- Nix builds are sandboxed with no network access during `buildPhase`; `nix/package.nix` receives `m3shapes` as a flake input (fetched by Nix's own fetcher during evaluation, same as Caelestia's `flake.nix`) and passes its store path to CMake via `-DFETCHCONTENT_SOURCE_DIR_M3SHAPES_EXTERNAL=<path>`, so `FetchContent` reuses that directory instead of attempting a sandboxed `git clone`.
- `Scripts/bash/install.sh`'s existing "build & install Hydra.Visual" step is unchanged — it already builds the entire `plugin/` CMake project, which now also produces the M3Shapes module.

## Verification performed

- `Scripts/dev/build-visual-plugin.sh` built both `Hydra.Visual` and the fetched `M3Shapes` module cleanly (`libm3shapes.so`, `libm3shapesplugin.so`, `qmldir`, `m3shapes.qmltypes` installed under `.build/visual-install/lib/qt6/qml/M3Shapes/`).
- A standalone smoke shell (`ShellRoot { FloatingWindow { MaterialShape { ... } } }`) launched via the real `qs` runtime with `QML_IMPORT_PATH` pointed at the build output: `import M3Shapes` resolved, `MaterialShape.Circle`/`MaterialShape.Heart` enum values read correctly (0 / 34), and the shape morphed live between Circle → Heart → Sunny → Cookie9Sided → Circle on screen (captured in `/tmp/hydra-m3shapes-smoke.png` during the session).

## Scope not included

No Caelestia branding, QML component code, or other Caelestia subsystem beyond the already-documented Blob port is incorporated by this decision. M3Shapes is fetched directly from its own upstream (`soramanew/m3shapes`), independent of the Caelestia checkout at `/home/raell/Projetos/Exemplos/Caelestia`.

The combined Hydra Shell work remains distributed under GPL-3.0-only; see [`CREDITS.md`](../CREDITS.md#visual-engine) and the root [`LICENSE`](../LICENSE).
