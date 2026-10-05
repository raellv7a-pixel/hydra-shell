---
name: hydra-ui-design
description: >-
  Operational UI/UX design intelligence and implementation standards for Hydra Shell.
  Applies Material 3, Framed-first panel spatial architecture, real Hydra design tokens,
  and QML component reuse patterns. Use whenever planning, reviewing, or implementing
  user-visible shell surfaces, panels, widgets, settings, dialogs, or controls.
license: MIT
compatibility: >-
  Designed for Hydra Shell development agents across Gemini, OpenAI/Codex, Claude, and OMP.
metadata:
  author: hydra-shell
  version: "1.0"
  target-framework: "Qt 6 / QML / Quickshell"
---

# Hydra UI Design Skill

## 1. Role and Authority

This skill is the **operational design intelligence layer** for AI agents working on Hydra Shell.
It translates durable design guidelines into concrete technical implementation instructions.

- **Canonical Authority:** `docs/UI_DESIGN.md` remains the human-authored, binding design authority. This skill does not replace `docs/UI_DESIGN.md`; it operationalizes it for automated agents.
- **Scope:** Covers visual hierarchy, Material 3 adaptation, Framed-first spatial docking, token usage, component reuse, panel lifecycles, and motion invariants.

### Dual Precedence Hierarchy

When making decisions, agents MUST strictly follow these two distinct hierarchies:

#### Hierarchy A: Design & Product Intent
1. **`AGENTS.md` + `docs/UI_DESIGN.md` + Sharpshooter Project Decisions** (supreme authority)
2. **`hydra-ui-design`** (this skill)
3. **`material-3`** (upstream design reference for semantic roles, shapes, and containers)
4. **`qt-ui-design`** (upstream reference for general desktop layout principles and perception)

> **Hydra Invariant:** Hydra's specific spatial and aesthetic rules always override generic recommendations from external skills.
> *Example:* Generic Material suggests a central floating dialog; Hydra requires ordinary shell panels to dock into the frame edge. Hydra wins.

#### Hierarchy B: Technical Implementation
1. **Hydra local architecture, actual code (`Commons/`, `Widgets/`, `Services/`), and Quickshell APIs** (supreme authority)
2. **`qt-qml`** (upstream technical reference for QML performance, binding idioms, and memory safety)
3. **Generic recommendations from external skills**

> **Implementation Invariant:** Upstream `material-3` is Compose-first (Jetpack Compose / Kotlin). Agents must NEVER transport Compose, Kotlin, Flutter, or web code into Hydra. Qt 6 / QML / Quickshell is the exclusive implementation runtime. Upstream `qt-ui-design` component recommendations never replace Hydra's verified primitives (`N*` widgets).

---

## 2. Core Design Rules

1. **Framed-First Architecture:**
   - `barType = "framed"` is the canonical visual and spatial architecture of Hydra Shell, not an optional decorative skin.
   - The Frame is a permanent structural surface. Ordinary shell panels visually emerge from and dock into the frame as natural surface extensions.
   - Docked panels eliminate hairline gaps using subpixel attachment overlap (`attachmentOverlap = 1`).
   - Ordinary panels MUST NEVER default to floating in the center of the screen without an evidenced UX rationale.
2. **Material 3 Foundation:**
   - Visual identity is grounded in Material You / Material Design 3 adapted to desktop shell workflows.
   - Modern Google Pixel / Android serves as primary reference for surface grouping, tonal elevation, and interaction rhythms.
   - Modern Apple / macOS / iOS serves as secondary reference for breathing room, optical clarity, progressive disclosure, and quiet polish.
3. **Shell Lineage & References:**
   - **Noctalia V4:** Historical functional ancestor only. **NEVER** use Noctalia V4 as a visual or styling reference.
   - **Noctalia V5:** Behavioral and structural reference when useful. **NEVER** clone Noctalia V5 aesthetically.
   - **Caelestia:** Structural reference strictly for spatial orchestration and edge docking concepts. **NEVER** clone Caelestia aesthetically (zero metaballs, organic blobs, or gooey shaders).
   - **DankMaterialShell (DMS):** Conceptual reference for QML/Material integration, not an API or component library to copy.
4. **Golden Invariants:**
   - *Color creates grouping.*
   - *Spacing creates separation.*
   - *Typography creates hierarchy.*
   - *Shape creates identity.*
   - *Motion creates continuity.*
   - *Borders are semantic, not structural decoration.* (No permanent outlines creating "boxes inside boxes").

---

## 3. Canonical Frame Regions

Hydra organizes display space into predictable canonical docking regions:

| Canonical Region | Functional Assignment | Docking & Interaction Model |
| :--- | :--- | :--- |
| **Top Center** | Dashboard (Control Center) | Attached to top frame edge; downward expansion |
| **Bottom Center** | Application Launcher | Attached to bottom frame edge; upward expansion |
| **Center Right** | Session Menu | Attached to right frame edge; vertically centered |
| **Center Left** | Portal / Screen Share Picker | Attached to left frame edge; vertically centered |
| **Bottom Left** | Window Switcher (Alt-Tab) | Grounded to bottom-left frame corner |
| **Widget Anchor** | System Tray & Widget Popouts | Dynamically anchored to initiating widget (`useButtonPosition`) |
| **Modal Overlay** | Polkit & Security Prompts | Centered overlay stacked above active panel; non-dismissable by outside click |
| *Top Left / Top Right / Bottom Right* | *Unassigned* | Reserved for future shell capabilities |

> **Tray Anchoring Invariant:** The System Tray is NOT hardcoded to Top Left. Tray menus and widget popouts dynamically follow their originating widget on the bar.

---

## 4. Panel Collision & Coexistence Contract

When two panels compete for display space:

1. **REPLACE:** One panel replaces another when they serve independent workflows and share a region.
2. **SHRINK:** Opposing panels dynamically reduce height or width to avoid geometric overlap (e.g., Dashboard from Top Center and Launcher from Bottom Center).
3. **SHIFT:** Neighboring panels displace laterally along shared edges.
4. **OVERLAY:** Strictly reserved for modal dependencies (e.g., Polkit authentication prompted by Launcher).

### Current State vs. Architectural Target
- **Current Runtime Baseline:** `PanelService` operates on a single normal panel baseline (`openedPanel`, `closingPanel`, and `modalPanel`).
- **Design Contract Today:** Every new panel MUST choose its canonical region and dock to the frame now.
- **Future Spatial Infrastructure:** Automated dynamic collision negotiation and multi-panel coexistence will be managed by a future spatial layout manager.

---

## 5. Anti-Patterns to Avoid

- **Hardcoded Colors:** Using `#hex` literals instead of semantic tokens (`Color.mSurface*`, `Color.mPrimary`, etc.).
- **Hardcoded Spacing/Radii:** Using magic numbers instead of `Style.margin*`, `Style.radius*`, or `Style.iRadius*`.
- **Boxes Inside Boxes:** Nesting bordered containers inside bordered cards without semantic justification.
- **Permanent Outlines:** Framing every button, chip, and card with high-contrast borders.
- **Arbitrary Center Popups:** Defaulting ordinary panels to floating in the center of the display.
- **Aesthetic Cloning:** Copying visual styling from Noctalia V4, Noctalia V5, Caelestia (blobs/gooey shaders), or DMS.
- **Gratuitous Glassmorphism/Gradients:** Adding blur or gradients purely for decorative flourish where Material tonal elevation belongs.
- **React/Tailwind Mental Models in QML:** Applying web-centric assumptions, CSS classes, or unnecessary wrapper layers.
- **Primitive Reinvention:** Writing `Rectangle + MouseArea` when `NButton`, `NIconButton`, `NToggle`, or `NBox` already exists.
- **Literal Android Emulation:** Treating Material 3 as a mandate to make the desktop shell look like an Android smartphone.

---

## 6. Frontend Creativity & Art Direction

For exceptional exploratory tasks or artistic critique, a frontend-design skill may be invoked for creative ideation. However, such skills have **zero authority** over `docs/UI_DESIGN.md`, `hydra-ui-design`, Material semantic contracts, or Hydra's Qt/QML architecture.

---

## 7. Reference Documents

Detailed operational guides are maintained in the `references/` directory:

- [Material 3 Adaptation (`references/material.md`)](references/material.md) — Semantic color mapping, container hierarchy, and theme compatibility.
- [Tokens Inventory (`references/tokens.md`)](references/tokens.md) — Comprehensive inventory of verified tokens in `Commons/Color.qml` and `Commons/Style.qml`.
- [Components Catalog (`references/components.md`)](references/components.md) — Confirmed reusable `N*` primitives, container patterns, and reuse rules.
- [Panels & Frame Architecture (`references/panels.md`)](references/panels.md) — `SmartPanel`, `PanelBackground`, 4-state curvature, and `PanelService`.
- [Motion & Easing (`references/motion.md`)](references/motion.md) — Animation duration tokens, easing curves, asymmetric hover timing, and performance gating.
