# Upstream Agent Skills Provenance

This directory stores vendored, versioned Agent Skills imported into Hydra Shell.
Upstream skill contents are kept intact in their respective directories.
All Hydra-specific design authority, overrides, tokens, and component mappings live in `hydra-ui-design/` and project documentation (`docs/UI_DESIGN.md`).

---

## 1. Material Design 3 (`material-3`)

- **Upstream Repository:** `https://github.com/hamen/material-3-skill`
- **Vendored Path:** `.agents/skills/material-3/`
- **Upstream Path:** `skills/material-3/`
- **Pinned Commit SHA:** `14385f2bf3804d8779f8b4db2604211f1e70b4c1`
- **Commit Date:** `2026-07-16 00:10:48 +0200`
- **Commit Message:** `docs(readme): "Made by" app links + Sponsor button (#10)`
- **License:** MIT License (Copyright (c) 2026 CWTI Ltd)
- **Imported At:** 2026-10-04
- **Authority / Purpose:** Reference authority for Material Design 3 (Material You / M3 Expressive) semantics: semantic color roles, container hierarchy, tonal surfaces, shape tokens, typography roles, spacing principles, and motion philosophy.
- **Hydra Architectural Constraint:** The upstream skill is Compose-first (Jetpack Compose / Kotlin). Hydra Shell is implemented in Qt 6 / QML / Quickshell. Material concepts and semantics serve strictly as design references. Jetpack Compose, Kotlin, Android Views, Flutter, and web implementations must NOT be imported into Hydra.

---

## 2. Qt QML (`qt-qml`)

- **Upstream Repository:** `https://github.com/TheQtCompanyRnD/agent-skills`
- **Vendored Path:** `.agents/skills/qt-qml/`
- **Upstream Path:** `skills/qt-qml/`
- **Pinned Commit SHA:** `4b3374472ebdaddb1585e6667441baf7028076ee`
- **Commit Date:** `2026-09-29 15:46:10 +0300`
- **Commit Message:** `Bump plugin version to 1.7.1`
- **License:** LicenseRef-Qt-Commercial OR BSD-3-Clause (Copyright (c) 2026, The Qt Company Ltd.)
- **Imported At:** 2026-10-04
- **Authority / Purpose:** Technical authority on Qt 6 / QML implementation standards: property binding efficiency, signal handling, Loader usage, memory lifecycle, component scoping, and QML engine idioms.
- **Hydra Architectural Constraint:** Hydra conventions and Quickshell-specific types take precedence when in conflict with generic Qt Quick Controls style guidelines.

---

## 3. Qt UI Design (`qt-ui-design`)

- **Upstream Repository:** `https://github.com/TheQtCompanyRnD/agent-skills`
- **Vendored Path:** `.agents/skills/qt-ui-design/`
- **Upstream Path:** `skills/qt-ui-design/`
- **Pinned Commit SHA:** `4b3374472ebdaddb1585e6667441baf7028076ee`
- **Commit Date:** `2026-09-29 15:46:10 +0300`
- **Commit Message:** `Bump plugin version to 1.7.1`
- **License:** LicenseRef-Qt-Commercial OR BSD-3-Clause (Copyright (c) 2026, The Qt Company Ltd.)
- **Imported At:** 2026-10-04
- **Authority / Purpose:** Reference principles for desktop and display interaction design in Qt/QML: F-shaped/Z-shaped scanning, cognitive load reduction, contrast and touch/pointer ergonomics, progressive disclosure, and modularity.
- **Hydra Architectural Constraint:** Generic desktop UI recommendations (such as central dialogs, default Qt Quick Controls styling, or geometry animation bans) are strictly subordinate to Hydra's Framed-first spatial system and `docs/UI_DESIGN.md`.

---

## Update Strategy (Manual Procedure)

To update an upstream skill safely in the future:

1. **Fetch upstream in a clean temporary checkout:**
   ```sh
   git clone --depth 1 <upstream-repository-url> /tmp/upstream-update
   ```
2. **Inspect upstream changelog and diff:**
   ```sh
   git -C /tmp/upstream-update log <pinned-sha>..HEAD --oneline
   git -C /tmp/upstream-update diff <pinned-sha>..HEAD -- <skill-path>
   ```
3. **Review conflict surface:**
   Verify whether upstream changes affect Hydra assumptions (e.g. new rules contradicting Framed panels or Quickshell architecture).
4. **Update vendored files:**
   Replace the vendored skill directory with the updated upstream version, preserving license files. Never edit upstream skill files in place to inject Hydra-specific rules.
5. **Update UPSTREAMS.md:**
   Record the new pinned commit SHA, date, commit message, and any observed behavioral changes.
6. **Keep Hydra skill separate:**
   Keep all Hydra-specific rules, tokens, and component references strictly inside `.agents/skills/hydra-ui-design/`.
7. **Validate and commit intentionally:**
   Run skill validation checks and commit through normal project workflow.
