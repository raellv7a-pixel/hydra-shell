.pragma library

// Flatpak run options may use either --option=value or --option value. Skip
// option operands before looking for the reverse-DNS application identity.
function flatpakId(command) {
  const values = Array.from(command || [], value => String(value));
  const binary = values.findIndex(value => value.split("/").pop() === "flatpak");
  if (binary < 0)
    return "";
  const run = values.indexOf("run", binary + 1);
  if (run < 0)
    return "";
  const takesValue = ["--installation", "--branch", "--arch", "--command", "--cwd", "--runtime", "--runtime-version", "--commit", "--runtime-commit", "--parent-pid", "--instance-id-fd", "--app-path", "--app-fd", "--usr-path", "--usr-fd", "--bind-fd", "--ro-bind-fd", "--env", "--env-fd", "--unset-env", "--filesystem", "--nofilesystem", "--device", "--nodevice", "--device-if", "--socket", "--nosocket", "--socket-if", "--share", "--unshare", "--share-if", "--allow", "--disallow", "--allow-if", "--persist", "--talk-name", "--no-talk-name", "--own-name", "--system-talk-name", "--system-no-talk-name", "--system-own-name", "--a11y-own-name", "--add-policy", "--remove-policy", "--usb", "--nousb", "--usb-list", "--usb-list-file"];
  for (let i = run + 1; i < values.length; i++) {
    const value = values[i];
    if (value === "--")
      continue;
    if (value.startsWith("-")) {
      if (takesValue.includes(value))
        i++;
      continue;
    }
    if (/^[A-Za-z_][A-Za-z0-9_-]*(\.[A-Za-z_][A-Za-z0-9_-]*){2,}$/.test(value))
      return value;
    // A non-option operand that is not an app id is not a removable identity.
    return "";
  }
  return "";
}

function indexRecords(records) {
  const result = {};
  for (const record of records) {
    result["package:" + record.type + ":" + record.name] = record;
    for (const alias of record.aliases) {
      const key = "alias:" + alias;
      // Ambiguous aliases must never silently choose another package.
      if (Object.prototype.hasOwnProperty.call(result, key) && (result[key]?.name !== record.name || result[key]?.type !== record.type))
        result[key] = null;
      else if (!Object.prototype.hasOwnProperty.call(result, key))
        result[key] = record;
    }
  }
  return result;
}

function updateCommand(info) {
  // Shelly 3.1.6 has granular update for native/AUR/Flatpak, not AppImage.
  return info.type === "appimage"
      ? ["shelly", "upgrade", "appimage", "--no-confirm"]
      : ["shelly", "update", info.type, info.name, "--no-confirm"];
}
