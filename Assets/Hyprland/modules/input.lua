-- Input defaults. Deliberately minimal: keyboard layout, pointer
-- acceleration and natural-scroll are personal preference, not something a
-- shipped default should impose — they stay at Hyprland's own built-in
-- defaults until the user sets them via the Settings panel. The one gesture
-- below is the exception: three-finger horizontal swipe to change workspace
-- is the near-universal touchpad convention across desktop environments and
-- is safe to ship unconditionally.
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})
