// Playback identity must come from application properties, never a sink's nick.
function appEntry(props, icons) {
  for (const candidate of [props["application.process.binary"]?.split("/").pop(), props["application.id"], props["application.name"]]) {
    if (!candidate)
      continue;
    const entry = icons.findAppEntry(candidate.toLowerCase());
    if (!entry)
      continue;
    const key = candidate.toLowerCase();
    const id = (entry.id || "").toLowerCase();
    const name = (entry.name || "").toLowerCase();
    const icon = (entry.icon || "").toLowerCase();
    if (id.includes(key) || name.includes(key) || icon.includes(key) || (id && key.includes(id.split(".").pop())))
      return entry;
  }
  return null;
}

function name(node, icons) {
  if (!node)
    return "Unknown App";
  const props = node.properties || {};
  const entry = appEntry(props, icons);
  if (entry?.name)
    return entry.name;
  const binary = (props["application.process.binary"] || "").split("/").pop();
  return props["application.name"] || props["application.id"] || binary || props["media.title"] || props["media.name"] || node.description || node.name || "Unknown App";
}

function icon(node, icons) {
  const props = node?.properties || {};
  const entry = appEntry(props, icons);
  const candidate = entry?.icon || props["application.icon-name"] || props["application.id"] || "application-x-executable";
  return icons.iconFromName(candidate, "application-x-executable");
}

function title(node, appName) {
  const props = node?.properties || {};
  const artist = (props["media.artist"] || "").trim();
  const track = (props["media.title"] || "").trim();
  const text = artist && track ? artist + " — " + track : track || artist || (props["media.name"] || "").trim();
  return text.toLowerCase() === appName.toLowerCase() ? "" : text;
}

function isPlayback(node) {
  if (!node?.isStream || !node.audio)
    return false;
  const props = node.properties || {};
  const mediaClass = props["media.class"] || "";
  const mediaRole = props["media.role"] || "";
  if (props["node.virtual"] || props["stream.capture.sink"] !== undefined || mediaClass.includes("Capture") || mediaClass.startsWith("Stream/Input") || mediaRole === "Capture")
    return false;
  if (node.name === "quickshell" || node.name === "noctalia-qs" || props["media.name"] === "quickshell" || props["media.name"] === "noctalia-qs")
    return false;
  return mediaClass.startsWith("Stream/Output") || (!mediaClass && !!(props["application.name"] || props["application.id"] || props["application.process.binary"]));
}
