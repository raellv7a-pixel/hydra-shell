-- Launch hydra-shell itself once Hyprland has finished starting. This is
-- what makes the shell start at all on a plain git/AUR install with no
-- systemd user service managing it (nix/home-module.nix's
-- `programs.noctalia-shell.systemd.enable` path already covers that case
-- and should be preferred when available — this hook is a no-op duplicate
-- launch attempt there, guarded by the pgrep check below).
hl.on("hyprland.start", function()
  hl.exec_cmd(
    "pgrep -x quickshell >/dev/null 2>&1 || " ..
    "command -v qs >/dev/null 2>&1 && qs -c hydra-shell -d"
  )
end)
