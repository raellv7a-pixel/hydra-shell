.pragma library
.import "../MonitorGeometry.js" as MonitorGeometry
// --- Backend interface ---
// Every backend module must export the following functions:
//
//   buildFetchCommand(cfg, defaults) -> Array<string>
//     Return the command (as an argv array) that reads the current output state.
//
//   parseOutputs(rawText) -> { outputs } | { error }
//     Parse the raw stdout text from the fetch command into a normalised array
//     of output objects. Return { error: string } on failure.
//
//   buildApplyCommand(outputs, cfg, defaults) -> { script } | { error }
//     Build a shell script string that applies the given draft outputs.
//     Return { error: string } if the command cannot be built.
//
//   buildConfigFileContent(outputs) -> { content } | { error }
//     Build a config file snippet for the given outputs (for copy-to-config).
//     Return { error: string } if the config cannot be built.
// ---

function extractSettings(cfg, defaults) {
  return {
    "hyprctlCommand": (cfg && cfg.hyprctlCommand) || (defaults && defaults.hyprctlCommand) || "hyprctl"
  };
}

function buildFetchCommand(cfg, defaults) {
  var settings = extractSettings(cfg, defaults);
  return [settings.hyprctlCommand, "monitors", "-j"];
}

function parseOutputs(rawText) {
  try {
    var parsed = JSON.parse(rawText || "[]");
    if (!Array.isArray(parsed)) {
      return { "error": "Hyprland monitor data must be an array." };
    }
    var outputs = [];

    for (var index = 0; index < parsed.length; index++) {
      var monitor = parsed[index];
      if (!monitor || monitor.disabled) {
        continue;
      }

      var width = Number(monitor.width);
      var height = Number(monitor.height);
      var refresh = normalizeRefreshRate(monitor.refreshRate);
      var scale = Number(monitor.scale);
      var transform = (monitor.transform !== undefined && monitor.transform !== null) ? Number(monitor.transform) : 0;
      var x = Number(monitor.x);
      var y = Number(monitor.y);
      if (typeof monitor.name !== "string" || !monitor.name ||
          !isFinite(width) || !isFinite(height) || width <= 0 || height <= 0 ||
          !isFinite(refresh) || refresh <= 0 || !isFinite(scale) || scale <= 0 ||
          !isFinite(transform) || !isFinite(x) || !isFinite(y)) {
        return { "error": "Hyprland returned incomplete geometry for monitor " + (monitor.name || index) + "." };
      }

      var logicalSize = MonitorGeometry.computeLogicalSize(width, height, scale, transform);
      var currentModeId = MonitorGeometry.canonicalizeModeId(width, height, refresh);

      // Hyprland advertises monitor modes in availableModes. Parse only
      // real modes, keeping the available-mode object shape
      // (id, width, height, refresh, label, preferred) for consumers.
      var modes = MonitorGeometry.parseAvailableModes(monitor.availableModes, width, height, refresh);

      outputs.push({
        "outputId": monitor.name,
        "name": monitor.name,
        "make": monitor.make || "",
        "model": monitor.model || "",
        "serial": monitor.serial || "",
        "mirror": monitor.mirrorOf && monitor.mirrorOf !== "none" ? monitor.mirrorOf : "",
        "active": true,
        "focused": !!monitor.focused,
        "isPrimary": (x === 0 && y === 0),
        "x": x,
        "y": y,
        "width": width,
        "height": height,
        "logicalWidth": logicalSize.width,
        "logicalHeight": logicalSize.height,
        "scale": scale,
        "transform": String(transform),
        "refresh": refresh,
        "modeId": currentModeId,
        "resolutionLabel": modeLabel(width, height, refresh),
        "availableModes": modes,
        "description": describeMonitor(monitor)
      });
    }

    return {
      "outputs": outputs
    };
  } catch (error) {
    return {
      "error": "Failed to parse Hyprland monitor data: " + error
    };
  }
}


// Single hl.monitor({...}) block for one output — shared by buildApplyCommand
// (live hyprctl eval) and buildLuaConfigFileContent (saved config) so the two
// can never drift apart.
function buildHlMonitorBlock(output) {
  if (output.active === false || output.disabled === true) {
    return 'hl.monitor({ output = "' + output.name + '", disabled = true })';
  }

  if (output.mirror && output.mirror !== "") {
    return 'hl.monitor({ output = "' + output.name + '", mode = "preferred", position = "auto", scale = 1, mirror = "' + output.mirror + '" })';
  }

  var resolution = output.width + "x" + output.height;
  var refresh = formatRefreshForCommand(output.refresh);
  if (refresh !== null && refresh !== "") {
    resolution += "@" + refresh;
  }

  var position = Math.round(output.x) + "x" + Math.round(output.y);
  var scale = sanitizeNumber(output.scale || 1);
  var transform = (output.transform !== undefined && output.transform !== null) ? Number(output.transform) : 0;

  var block = 'hl.monitor({ output = "' + output.name + '", mode = "' + resolution + '", position = "' + position + '", scale = ' + scale;
  if (transform !== 0) {
    block += ", transform = " + transform;
  }
  block += " })";
  return block;
}

// Hyprland running its Lua config rejects `hyprctl keyword` outright — the
// only live-apply path is `hyprctl eval "<hl.monitor(...) calls>"`. See
// PLANO_INTEGRACAO_HYPRMOD.md §2.5/§2.6/§4.1 for the confirmed evidence.
function buildApplyCommand(outputs, cfg, defaults) {
  if (!outputs || outputs.length === 0) {
    return {
      "error": "No outputs available to apply."
    };
  }

  var hyprctlCommand = extractSettings(cfg, defaults).hyprctlCommand;
  var blocks = [];

  for (var index = 0; index < outputs.length; index++) {
    var output = outputs[index];
    if (!output) continue;
    blocks.push(buildHlMonitorBlock(output));
  }

  if (blocks.length === 0) {
    return {
      "error": "There are no outputs to configure."
    };
  }

  // Leading space defends against hyprctl's arg parser mistaking a snippet
  // for a flag if it ever starts with "-"; harmless here (blocks start with
  // "hl.") but kept for consistency with HyprlandEvalService.evalLua().
  var luaSnippet = " " + blocks.join("; ");
  return {
    "script": shellQuote(hyprctlCommand) + " eval " + shellQuote(luaSnippet)
  };
}

function buildConfigFileContent(outputs) {
  if (!outputs || outputs.length === 0) {
    return {
      "error": "No outputs available to configure."
    };
  }

  var lines = [];
  for (var index = 0; index < outputs.length; index++) {
    var output = outputs[index];
    if (!output) continue;

    if (output.active === false || output.disabled === true) {
      lines.push("monitor=" + output.name + ",disable");
      continue;
    }

    if (output.mirror && output.mirror !== "") {
      lines.push("monitor=" + output.name + ",preferred,auto,1,mirror," + output.mirror);
      continue;
    }

    var resolution = output.width + "x" + output.height;
    var refresh = formatRefreshForCommand(output.refresh);
    if (refresh !== null && refresh !== "") {
      resolution += "@" + refresh;
    }

    var position = Math.round(output.x) + "x" + Math.round(output.y);
    var scale = sanitizeNumber(output.scale || 1);
    var transform = (output.transform !== undefined && output.transform !== null) ? String(output.transform) : "0";

    var line = "monitor=" + output.name + "," + resolution + "," + position + "," + scale;
    if (transform !== "0") {
      line += ",transform," + transform;
    }
    lines.push(line);
  }

  return {
    "content": lines.join("\n")
  };
}

function buildLuaConfigFileContent(outputs) {
  if (!outputs || outputs.length === 0) {
    return { "error": "No outputs available to configure." };
  }

  var lines = [];
  for (var index = 0; index < outputs.length; index++) {
    var output = outputs[index];
    if (!output) continue;

    if (output.active === false || output.disabled === true) {
      lines.push('hl.monitor({\n    output = "' + output.name + '",\n    disabled = true\n})');
      continue;
    }

    if (output.mirror && output.mirror !== "") {
      lines.push('hl.monitor({\n    output = "' + output.name + '",\n    mode = "preferred",\n    position = "auto",\n    scale = 1,\n    mirror = "' + output.mirror + '"\n})');
      continue;
    }

    var resolution = output.width + "x" + output.height;
    var refresh = formatRefreshForCommand(output.refresh);
    if (refresh !== null && refresh !== "") {
      resolution += "@" + refresh;
    }

    var position = Math.round(output.x) + "x" + Math.round(output.y);
    var scale = sanitizeNumber(output.scale || 1);
    var transform = (output.transform !== undefined && output.transform !== null) ? Number(output.transform) : 0;

    var block = 'hl.monitor({\n' +
                '    output = "' + output.name + '",\n' +
                '    mode = "' + resolution + '",\n' +
                '    position = "' + position + '",\n' +
                '    scale = ' + scale;

    if (transform !== 0) {
      block += ',\n    transform = ' + transform;
    }
    block += '\n})';
    lines.push(block);
  }

  return { "content": lines.join("\n\n") };
}


function modeIdFromRes(width, height, refresh) {
  return width + "x" + height + "@" + refresh;
}

function modeLabel(width, height, refresh) {
  var text = width + "x" + height;
  if (refresh && refresh > 0) {
    text += " @ " + refreshToHzString(refresh) + " Hz";
  }
  return text;
}

function refreshToHzString(refresh) {
  return Number(refresh).toFixed(2).replace(/\.00$/, "").replace(/(\.\d*[1-9])0+$/, "$1");
}

function normalizeRefreshRate(refresh) {
  var numeric = Number(refresh);
  if (!isFinite(numeric) || numeric <= 0) {
    return 0;
  }

  if (numeric >= 1000) {
    return numeric / 1000;
  }

  return numeric;
}

function formatRefreshForCommand(refresh) {
  if (refresh === undefined || refresh === null || refresh === "") {
    return "";
  }

  var normalized = normalizeRefreshRate(refresh);
  if (!isFinite(normalized) || normalized < 1 || normalized > 1000) {
    return null;
  }

  return refreshToHzString(normalized);
}

function sanitizeNumber(value) {
  var numeric = Number(value);
  if (!isFinite(numeric) || numeric <= 0) {
    return "1";
  }
  return numeric.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
}

function describeMonitor(monitor) {
  var parts = [];
  if (monitor.make) {
    parts.push(monitor.make);
  }
  if (monitor.model) {
    parts.push(monitor.model);
  }
  if (monitor.serial) {
    parts.push(monitor.serial);
  }
  return parts.join(" ").trim();
}

function shellQuote(text) {
  var value = String(text === undefined || text === null ? "" : text);
  return "'" + value.replace(/'/g, "'\\''") + "'";
}
