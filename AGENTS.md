<!-- prowl-agent -->
## Prowl project context

This repo has a Prowl index of its files, symbols, and how they connect. To find
code, read one symbol, trace who calls it, or check what a change touches,
**query Prowl first** -- do not grep or read whole files just to locate things.
Prowl reindexes what changed before each query, so answers stay current, and it
returns ranked, cited file:line results in one call instead of a grep hit list
you then open files to disambiguate.

The same index is reachable two ways, and every agent should know both:

- **Preferred -- Prowl MCP tools** (they appear in your tool list when your
  harness wires Prowl as an MCP server): search_context (where/how does X work),
  read_symbol (one symbol's source), outline (a file's structure, no bodies),
  find_references (call sites), analyze_change (blast radius before an edit), and
  sketch_ui (how a UI looks, from source).
- **Opt-in -- the prowl-agent CLI** (same capabilities, for when MCP is not
  wired): overview, find <name>, outline <path>, def <name>, references <name>,
  callers|callees|relations <path>, impact <path>, search <text>, wip, and
  changed / doctor after edits.

Keep grep and glob for literal-string and filename scans only. CLI output is
token-lean TOON by default; add --format human|toon|json|markdown.
<!-- /prowl-agent -->

<!-- prowl-agent:map -->
## Prowl project map

Auto-generated from the Prowl index, refreshed on each `overview`/`init`. Prefer retrieving from Prowl (and reading the cited files) over grepping or relying on training memory; this is the current shape of the repo.

- size: 730 files, 82835 symbols, 4884 edges (resolved 3822, external deps 108, unresolved 954)
- languages: qml:522 json:76 bash:31 python:27 javascript:14 markdown:12 css:10 lua:10
- subsystems: Modules/Panels(231,qml) · Widgets(53,qml) · Modules/Bar(44,qml) · Commons/Migrations(26,qml) · Modules/ScreenToolkit(21,qml) · Services/UI(17,qml) · Services/System(16,qml) · Commons(12,qml)
- entrypoints: shell.qml · Widgets/NInputAction.qml · Assets/Hyprland/hyprland.lua · Modules/Cards/AudioCard.qml · Modules/Cards/BrightnessCard.qml · Modules/Cards/ShortcutsCard.qml · Modules/Cards/SystemMonitorCard.qml · Modules/Polkit/PolkitWindow.qml · (+79 more)
- central files (most depended-on): Commons/Settings.qml · Commons/Logger.qml · Commons/Time.qml · Commons/I18n.qml · Commons/Style.qml
- read these guides first: README.md

Depth on demand: `prowl-agent find|def|outline|references <name>`, `search <text>`, `context search "<question>"`, `sketch <ui>`.
<!-- /prowl-agent:map -->
