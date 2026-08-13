<!-- prowl-agent -->
## Prowl project context

This repo has a Prowl index. To find code, read it, trace how it connects, or
check what a change touches, query Prowl first, and prefer reading one symbol
(def) or a file's structure (outline) over opening whole files; use grep only
for plain-text scans. Prowl reindexes what changed before each query, so answers
stay current, and a symbol lookup returns ranked, cited file:line results in one
call rather than a grep hit list you then open files to disambiguate.

- Map the project: `prowl-agent overview`
- Find a symbol, setting, or component: `prowl-agent find <name>`
- See a file's structure without reading it: `prowl-agent outline <path>` (symbols and signatures, no bodies)
- Read one symbol instead of the whole file: `prowl-agent def <name>`
- Where a symbol is used (its callers): `prowl-agent references <name>`
- How files connect: `prowl-agent callers|callees|relations <path>`
- Blast radius before an edit: `prowl-agent impact <path>`
- Search text or meaning: `prowl-agent search <text>`
- Resume unfinished work: `prowl-agent wip`
- After edits: `prowl-agent changed` and `prowl-agent doctor`

Output is token-lean TOON by default; add `--format human|toon|json|markdown`.
MCP clients can run `prowl-agent serve`.
<!-- /prowl-agent -->
