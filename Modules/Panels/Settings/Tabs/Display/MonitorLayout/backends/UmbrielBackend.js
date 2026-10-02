.pragma library
.import "../MonitorGeometry.js" as MonitorGeometry

var transforms = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"];

function buildFetchCommand() { return ["umbriel", "outputs", "--json"]; }

function parseOutputs(text) {
  try {
    const entries = JSON.parse(text);
    if (!Array.isArray(entries))
      throw new Error("Umbriel outputs must be an array");
    const outputs = entries.map(entry => {
      const modes = (entry.modes || []).map(mode => ({
        id: MonitorGeometry.canonicalizeModeId(mode.width, mode.height, mode.refresh_mhz / 1000),
        width: mode.width, height: mode.height, refresh: mode.refresh_mhz / 1000,
        preferred: mode.preferred, label: mode.width + "×" + mode.height + " @ " + (mode.refresh_mhz / 1000).toFixed(2) + " Hz"
      }));
      const mode = (entry.modes || []).find(mode => mode.current) || (entry.enabled === false ? (entry.modes || []).find(mode => mode.preferred) : null);
      if (!entry.name || !mode || !Number.isFinite(entry.scale) || !entry.position || !transforms.includes(entry.transform))
        throw new Error("Incomplete Umbriel geometry: " + entry.name);
      const transform = transforms.indexOf(entry.transform);
      const size = MonitorGeometry.computeLogicalSize(mode.width, mode.height, entry.scale, transform);
      return {
        outputId: entry.name, name: entry.name, description: entry.description,
        make: entry.make, model: entry.model, serial: entry.serial,
        active: entry.enabled, disabled: !entry.enabled,
        x: entry.position.x, y: entry.position.y, isPrimary: entry.position.x === 0 && entry.position.y === 0,
        width: mode.width, height: mode.height, refresh: mode.refresh_mhz / 1000,
        logicalWidth: size.width, logicalHeight: size.height, scale: entry.scale,
        transform: String(transform), modeId: MonitorGeometry.canonicalizeModeId(mode.width, mode.height, mode.refresh_mhz / 1000),
        resolutionLabel: mode.width + "×" + mode.height, availableModes: modes
      };
    });
    return { outputs: outputs };
  } catch (error) {
    return { error: String(error) };
  }
}

function shellQuote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'"; }

function buildApplyCommand(outputs, cfg) {
  if (!outputs.length || !cfg?.script)
    return { error: "No Umbriel configuration writer or outputs" };
  return { script: "python3 " + shellQuote(cfg.script) + " outputs " + shellQuote(JSON.stringify(outputs)) };
}

function buildConfigFileContent(outputs) {
  const lines = ["# Hydra-owned Umbriel outputs"];
  for (const output of outputs) {
    lines.push("", "[output." + JSON.stringify(output.name) + "]", "enabled = " + String(output.active !== false && !output.disabled));
    if (output.active !== false && !output.disabled) {
      lines.push("mode = " + JSON.stringify(output.width + "x" + output.height + "@" + output.refresh),
                 "position = [" + output.x + ", " + output.y + "]", "scale = " + output.scale,
                 "transform = " + JSON.stringify(transforms[Number(output.transform)]));
    }
  }
  return { content: lines.join("\n") + "\n" };
}
