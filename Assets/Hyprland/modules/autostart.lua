-- Launch hydra-shell itself once Hyprland has finished starting. This is
-- what makes the shell start at all on a plain git/AUR install with no
-- systemd user service managing it (nix/home-module.nix's
-- `programs.hydra-shell.systemd.enable` path already covers that case
-- and should be preferred when available — this hook is a no-op duplicate
-- launch attempt there, guarded by the pgrep check below).
hl.on("hyprland.start", function()
  local migrate = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) ..
    "/quickshell/hydra-shell/Scripts/bash/migrate-noctalia-config.sh"

  -- Single command: the pre-rebrand Noctalia config/cache dirs must be renamed
  -- before the shell reads them. The migration is a no-op once done.
  hl.exec_cmd(
    "{ test -x " .. migrate .. " && " .. migrate .. "; }; " ..
    "pgrep -x quickshell >/dev/null 2>&1 || " ..
    "command -v qs >/dev/null 2>&1 && qs -c hydra-shell -d"
  )
end)
