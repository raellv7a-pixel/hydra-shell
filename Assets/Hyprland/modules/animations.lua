-- Animation curves + per-leaf overrides. Two curves (a settle-in "smooth" and
-- a snappier "quick" for direct-manipulation feedback) cover every leaf
-- below; the Settings panel's Animações sub-tab (Fase 2, with a bezier
-- editor) lets a user add more or retune these without touching this file —
-- edits land in hydra-shell/settings.lua, which is required after this
-- module.
hl.curve("smooth", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "quick" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "quick" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "smooth", style = "slidefadevert -30%" })
