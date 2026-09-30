# Hydra AI development workflow

## Authority and recovery

- Git and the current checkout are authoritative for code and changed files.
- Beads is the operational task ledger. Do not maintain a parallel Markdown TODO list.
- Prowl is code discovery and bounded context. Sharpshooter stores durable decisions; Prowl Knowledge stores accepted technical facts backed by code anchors.
- Memory is heuristic. Verify it against current code, Git, and current user intent.

At session start:

```sh
bd ready --json
bd show <issue-id> --json
bd update <issue-id> --claim
```

Before a model/session change, add a Beads comment with the last action/result, branch and commit, modified files, checks, current failure, and exact next step. At completion, close the issue with a reason. The Beads CLI is preferred over an additional MCP server.

Every agent handoff is self-contained: issue ID, objective, branch/current commit, plan, target files, relevant Prowl citations, constraints, acceptance criteria, tests, known risks, and previous attempts. Do not send the parent transcript.

## Role routing and agents

Project agents are in `.omp/agents/`; their frontmatter uses only global roles:

| Agent | Role | Responsibility |
|---|---|---|
| `scout` | `@smol` | Read-only Prowl exploration; evidence and context packet |
| `planner` | `@plan` | Read-only short plan, acceptance criteria, tests, risks |
| `executor` | `@task` | Approved implementation, checks, preview, Beads progress |
| `reviewer` | `@review` | Read-only findings against issue, plan, diff, tests, and logs |
| `architect` | `@slow` | Exceptional, explicit read-only escalation only |

Small low-risk edits may stay with Luna or `@tiny`. Normal functional work uses Scout/Prowl → Executor → Reviewer. Multi-file, lifecycle, shared-service, animation, or architectural work uses Scout → Planner → Beads plan/claim → Executor → Reviewer. The reviewer receives the objective, plan, acceptance criteria, diff, test results, and limitations—not the whole repository. A rejected or structurally conflicting plan returns to the orchestrator and Beads before redesign.

`@slow` is not an automatic fallback. Escalate only after planner/executor/reviewer fail, a deep architectural contradiction, a hard lifecycle/race/state bug, or an explicit user request. Do not put concrete model selectors, account IDs, or account policy in this repository. Global model roles and account routing remain global.

## Prowl

This host installs Prowl as `prowl` v0.16.8. `prowl-agent` is a stale executable name; the OMP MCP server invokes `prowl serve --mcp-surface core`.

Use bounded discovery before structural reads:

```sh
prowl overview
prowl search "<behavior or component>"
prowl find <symbol>
prowl def <symbol>
prowl outline <path>
prowl references <symbol>
prowl impact <path>
prowl context search "<focused question>" --budget-tokens 2000
prowl doctor --fail-on error
```

Prefer a roughly 1,500–2,500 token context packet. Read cited symbols/ranges only. Use grep/glob for literal text and filename scans. The index/database is derived cache; accepted knowledge belongs in `.prowl/knowledge/`. Initialize/list/lint with `prowl knowledge init`, `prowl knowledge list`, and `prowl knowledge lint`. Review proposals before acceptance; do not use knowledge as a diary or accept guesses.

Prowl AI assistance is configured in `.prowl/config.toml` using `provider = "agent"` and the role-routed command `omp -p --model @smol`. It has no hardcoded model selector. Do not run setup against all editor integrations casually; inspect `prowl init --dry-run` first.

## OMP project configuration and memory

`.omp/config.yml` is project-local. It selects Sharpshooter, enables OMP's conversation checkpoint, prioritizes local `shake` then `snapcompact` before remote/handoff/soft compaction, and sets conservative per-agent compaction thresholds. No global OMP config, model role, account policy, credential, or backend is changed here.

Sharpshooter is for decisions learned through real testing (architecture, UX constraints, conventions, proven pitfalls), not progress, logs, commands, or TODOs. A conversation checkpoint/rewind is not Git and does not snapshot files. Keep the Git working tree and Beads state correct independently.

## Lab, preview, deploy, rollback

- Lab/source: `~/Projetos/hydra-shell`, branch `legacy-v4`.
- Active shell: `~/.config/quickshell/hydra-shell`; edit only the Lab.
- State records: `$XDG_STATE_HOME/hydra-shell-lab`, default `~/.local/state/hydra-shell-lab`.
- `Scripts/dev/lab-status.sh` is local-only and does not fetch the Git remote.
- `Scripts/dev/lab-preview.sh` runs `qs -p <Lab>` in the foreground, records its PID and log, and terminates only that preview when stopped.
- Run pinned QML formatting/parser checks and QML lint for changed QML; `lab-sync.sh` excludes deleted QML paths and calls `qmllint.sh` with Quickshell's generated QML modules and Hydra's `qs.*` source modules. Set `HYDRA_QUICKSHELL_QML_MODULES_DIR` to the directory containing `Quickshell/qmldir` when automatic discovery cannot identify the active modules. Run `prowl doctor --fail-on error`.
- Repository-wide `qmlfmt.sh --check` currently reports 45 existing QML files needing formatting under pinned Qt 6.10.3. Format/check only changed QML paths; do not mass-format the baseline during infrastructure work.
- Visually/behaviorally validate the exact preview commit. Deploy with `Scripts/dev/lab-sync.sh --preview-validated <full-40-character-commit>`. It requires a clean Lab/active checkout, exactly one active `qs -c hydra-shell` process, recorded LKG, checks, and a fast-forward from the local Lab only. It never pushes or fetches from the network remote.
- Quickshell's file watcher reloads changed source. Check the active UI/logs; only then record success with `Scripts/dev/lab-mark-good.sh <commit> --visual-confirmed`.
- `Scripts/dev/lab-rollback.sh` restores the recorded LKG offline. It refuses dirty state or an unexpected active HEAD. Do not manually overwrite the active tree to bypass these guards.

- Rollback state under `$XDG_STATE_HOME/hydra-shell-lab` records commit IDs and validation status; the local Git commit/ref is the recovery source, not a copied runtime backup. A user Hyprland `hyprland.lua` existed before adoption and is preserved in `~/.config/hypr/hydra-shell-backup-20260929-204118`. The previous Lab symlinks and `user.lua` are backed up in `~/.config/hypr/hydra-shell-backup-20260929-211915`; current `hyprland.lua` and `modules/` point into the active checkout.

## Hydra baseline and scope

The project is Hydra Shell on `legacy-v4`, derived from Noctalia V4. Do not substitute Noctalia V5. Before any Hydra feature work, run the clean baseline and inspect workspaces, icons/assets, pills, spacing, hit areas, and glyph alignment. If the historical alignment defect reproduces, create a READY Beads bug with commit, screenshots/logs, visible components, expected/current behavior, and candidate files; do not fix it in infrastructure bootstrap.

No UI feature belongs in Phase 2. Avoid remote install pipes. Audit repository installers before running them; the legacy Hydra installer includes system package/service operations and remote clone/update steps. The Hydra-compatible Quickshell fork is installed user-locally at `$HOME/.local/bin`; the active shell has been launched and visually validated on DP-1/DP-2. The adopted Hyprland `hyprland.start` hook runs `qs -c hydra-shell -d`; `user.lua` adds `$HOME/.local/bin` to the Hyprland session PATH without adding a second autostart mechanism. The historical icon/workspace alignment regression was initially marked NOT REPRODUCED on the clean `legacy-v4` baseline, but subsequent user report and instrumented Lab raster confirm issue hydra-a8h.

## UI/UX acceptance policy

Any change that adds/removes a setting, changes configurable behavior, alters layout, or modifies visible UI MUST include an explicit UX/UI review. Functional correctness alone is insufficient: controls and surfaces must remain clear, coherent, and consistent with Hydra's Material 3 design system, using existing `Style`, `Color`, `N*` components, spacing, radii, and typography. Do not treat a UI change as complete until its actual preview has been visually inspected.
