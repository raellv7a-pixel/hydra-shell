<!-- prowl-agent -->
## Prowl project context

This repo has a Prowl index of its files, symbols, and how they connect. For any
semantic or structural question -- where code is, what it does, who calls it, or
what a change touches -- **run the read-only prowl CLI first**; do not grep or
read whole files just to locate things. Prowl reindexes what changed before each
query, so answers stay current and are cited to file:line, returned in one call
instead of a grep hit list you then open files to disambiguate.

| Question | First command |
|---|---|
| Map the repository | `prowl overview` |
| Locate a feature or concept | `prowl search "<question>"` |
| Locate a named symbol | `prowl find <name>` |
| Read one symbol's source | `prowl def <name-or-id>` |
| Inspect a file's structure | `prowl outline <path>` |
| Trace who uses a symbol | `prowl references <name-or-id>` |
| Size a change's blast radius | `prowl impact <path>` |
| Inspect uncommitted work | `prowl wip` / `prowl changed` |
| Read a located line range | `prowl peek <file:start-end>` |

Keep grep for exact literal or regex text and glob for filename patterns. CLI
output is token-lean TOON by default; add --format human|toon|json|markdown. If
your harness also wires Prowl as an MCP server, the same index is reachable
there; the CLI needs no server and is the first choice.
<!-- /prowl-agent -->

<!-- prowl-agent:map -->
## Prowl project map

Auto-generated from the Prowl index, refreshed on each `overview`/`init`. Prefer retrieving from Prowl (and reading the cited files) over grepping or relying on training memory; this is the current shape of the repo.

- size: 839 files, 83948 symbols, 5481 edges (resolved 4087, external deps 399, unresolved 995)
- languages: qml:573 json:76 python:56 bash:37 markdown:30 javascript:24 css:13 toml:11
- subsystems: Modules/Panels(275,qml) · Widgets(56,qml) · Modules/Bar(44,qml) · Commons/Migrations(28,qml) · Modules/ScreenToolkit(21,qml) · Services/UI(21,qml) · Modules/MainScreen(14,qml) · Services/System(14,qml)
- entrypoints: shell.qml · Modules/Cards/MediaCard.qml · Modules/Panels/Settings/Bar/WidgetSettings/CustomButtonSettings.qml · Modules/Panels/Settings/DesktopWidgets/WidgetSettings/ClockSettings.qml · Modules/Panels/SessionMenu/SessionMenu.qml · Modules/Panels/Settings/Bar/WidgetSettings/ClockSettings.qml · Modules/Panels/Wallpaper/WallhavenSettingsPopup.qml · Modules/Cards/ProfileCard.qml · (+73 more)
- central files (most depended-on): Commons/Settings.qml · Commons/Logger.qml · Commons/Color.qml · Commons/Time.qml · Commons/I18n.qml
- read these guides first: README.md · AGENTS.md · docs/AI_DEVELOPMENT.md · docs/UI_DESIGN.md

Depth on demand: `prowl find|def|outline|references <name>`, `search <text>`, `context search "<question>"`, `sketch <ui>`.
<!-- /prowl-agent:map -->
# Hydra development workflow

- **Authority:** Git and the current working tree define code. Beads is task state. Prowl is code discovery. Sharpshooter stores only durable decisions; accepted Prowl Knowledge stores evidence-linked technical facts. Memory never overrides current code or user intent.
- At session start run `bd ready --json`; inspect each relevant issue with `bd show <id> --json`, then claim it with `bd update <id> --claim`. Record significant progress, failures, changed files, test results, and the exact next action in Beads. Do not keep a parallel Markdown TODO list.
- Before delegation, pass a self-contained handoff: issue ID, objective, branch/current commit, plan, target files, Prowl evidence, constraints, acceptance criteria, tests, and known risks. Never rely on parent chat history.
- Small, low-risk changes: Luna or `@tiny`. Normal functional change: Scout/Prowl → Executor (`@task`) → Reviewer (`@review`). Multi-file, lifecycle, shared-service, animation, or architecture work: Scout (`@smol`) → Planner (`@plan`) → Beads plan/claim → Executor (`@task`) → Reviewer (`@review`). Planner and Reviewer report only; Scout is read-only.
- Use only global role aliases (`@default`, `@smol`, `@tiny`, `@task`, `@plan`, `@review`, `@vision`, `@commit`, `@slow`). Do not put concrete model selectors or account policy in project agents. `@slow`/Astra is exceptional: escalate only after planner/executor/reviewer fail, a deep architectural contradiction, a hard lifecycle/race/state bug, or explicit user choice.
- Query Prowl before structural code search; use a bounded context packet (`prowl context search "<question>" --budget-tokens 2000`), then read only cited symbols/ranges. Use `grep`/`glob` for literal text and filenames. Run Prowl doctor after code changes.
- Re-check current Git/code before acting on Sharpshooter or remembered advice. Preserve uncommitted work. Never store credentials in project files.
- Functional edits happen in the Lab checkout only. Run checks, preview the exact commit, validate behavior/UI, then request Reviewer findings before deployment. Deploy only with the validated full commit hash; never push from the Lab. Use `Scripts/dev/lab-rollback.sh` only after its clean-tree and recorded-deploy guards pass.
- For incomplete work, update Beads before model/session changes: status, last action/result, branch/commit, changed files, tests, current failure, and exact next action. On completion, close with a clear reason.
- Bootstrap work must not introduce Hydra UI behavior. If a clean baseline reproduces the workspace/icon alignment bug, record it as the first ready Beads bug; do not fix it during infrastructure setup.
- For any visible UI/UX work, read `docs/UI_DESIGN.md` and `.agents/skills/hydra-ui-design/` before planning or editing.

## Agent skills and visible UI work

For any user-visible surface, panel, settings, dialog, widget, or layout work:

1. **Mandatory core guidance:** Read `docs/UI_DESIGN.md` (authoritative design policy) and load `.agents/skills/hydra-ui-design` (operational rules, real tokens, component catalog, and panel contracts).
2. **Supporting design reference:** Consult `.agents/skills/material-3` for Material Design 3 semantic color roles, container hierarchy, and tonal principles (reference only; do not import Jetpack Compose or Kotlin implementations). Consult `.agents/skills/qt-ui-design` for display ergonomics and perceptual design principles.
3. **Technical implementation:** Consult `.agents/skills/qt-qml` for QML coding best practices, binding efficiency, and Loader lifecycle. Hydra's verified architecture and Quickshell components always take precedence over generic Qt advice.

See `docs/AI_DEVELOPMENT.md` for operational commands and recovery details.
