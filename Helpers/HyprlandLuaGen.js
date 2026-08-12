// -----------------------------------------------------
// Pure Lua generator for the Hyprland Settings tab
// (PLANO_INTEGRACAO_HYPRMOD.md §3.2/§5).
//
// Every function here is `data -> string`, no I/O. Two callers:
//   - Services/Compositor/HyprlandLuaWriter.qml calls buildSettingsLua()/
//     buildRebindsLua() to regenerate ~/.config/hypr/hydra-shell/*.lua on Save.
//   - Services/Compositor/HyprlandEvalService.qml calls the section builders
//     directly (appearance only, today) to build a `hyprctl eval` snippet for
//     live preview without touching disk.
//
// DEFAULT_APPEARANCE mirrors Assets/Hyprland/modules/decoration.lua +
// animations.lua's hl.config leaves exactly — keep the two in sync by hand;
// this is what "only emit what diverges" diffs against, and what every
// SubTab's "Restaurar padrão" button restores.
var DEFAULT_APPEARANCE = {
  gapsIn: 5,
  gapsOut: 10,
  borderSize: 2,
  layout: "dwindle",
  resizeOnBorder: true,
  allowTearing: false,
  rounding: 10,
  roundingPower: 2,
  activeOpacity: 1.0,
  inactiveOpacity: 1.0,
  shadowEnabled: true,
  shadowRange: 4,
  shadowRenderPower: 3,
  blurEnabled: true,
  blurSize: 8,
  blurPasses: 2,
  blurXray: false,
  animationsEnabled: true
};

// -----------------------------------------------------
// Lua literal helpers. Every value that can contain arbitrary user input
// (window rule regexes, env var values, exec commands, descriptions) MUST go
// through luaStr — never string-concatenate untrusted text directly into
// generated Lua, or a value containing a `"` breaks out of the string and
// the rest is interpreted as code (the exact class of bug flagged in
// ryoku-arch's own CHANGELOG for hl.monitor(), see PLANO_INTEGRACAO_HYPRMOD.md
// research notes).
function luaStr(value) {
  var s = value === undefined || value === null ? "" : String(value);
  return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
}

function luaBool(value) {
  return value ? "true" : "false";
}

function luaNum(value) {
  var n = Number(value);
  return isFinite(n) ? String(n) : "0";
}

// -----------------------------------------------------
function isDefault(key, value) {
  return DEFAULT_APPEARANCE[key] === value;
}

// Builds the single `hl.config({...})` block, only diverging leaves.
// Returns "" (not even `hl.config({})`) when nothing diverges.
function genAppearance(appearance) {
  // Merge over the full default set first: a partial/older-schema object
  // (a hand-edited settings.json, a pre-migration save) must fall through
  // to shipped defaults per-field, never be treated as "every missing key
  // diverges" — an unset key is not a divergence.
  var merged = Object.assign({}, DEFAULT_APPEARANCE, appearance || {});
  appearance = merged;
  var general = [];
  var decoration = [];
  var shadow = [];
  var blur = [];
  var animations = [];

  if (!isDefault("gapsIn", appearance.gapsIn))
    general.push("gaps_in = " + luaNum(appearance.gapsIn));
  if (!isDefault("gapsOut", appearance.gapsOut))
    general.push("gaps_out = " + luaNum(appearance.gapsOut));
  if (!isDefault("borderSize", appearance.borderSize))
    general.push("border_size = " + luaNum(appearance.borderSize));
  if (!isDefault("layout", appearance.layout))
    general.push("layout = " + luaStr(appearance.layout));
  if (!isDefault("resizeOnBorder", appearance.resizeOnBorder))
    general.push("resize_on_border = " + luaBool(appearance.resizeOnBorder));
  if (!isDefault("allowTearing", appearance.allowTearing))
    general.push("allow_tearing = " + luaBool(appearance.allowTearing));

  if (!isDefault("rounding", appearance.rounding))
    decoration.push("rounding = " + luaNum(appearance.rounding));
  if (!isDefault("roundingPower", appearance.roundingPower))
    decoration.push("rounding_power = " + luaNum(appearance.roundingPower));
  if (!isDefault("activeOpacity", appearance.activeOpacity))
    decoration.push("active_opacity = " + luaNum(appearance.activeOpacity));
  if (!isDefault("inactiveOpacity", appearance.inactiveOpacity))
    decoration.push("inactive_opacity = " + luaNum(appearance.inactiveOpacity));

  if (!isDefault("shadowEnabled", appearance.shadowEnabled))
    shadow.push("enabled = " + luaBool(appearance.shadowEnabled));
  if (!isDefault("shadowRange", appearance.shadowRange))
    shadow.push("range = " + luaNum(appearance.shadowRange));
  if (!isDefault("shadowRenderPower", appearance.shadowRenderPower))
    shadow.push("render_power = " + luaNum(appearance.shadowRenderPower));
  if (shadow.length)
    decoration.push("shadow = {\n      " + shadow.join(",\n      ") + ",\n    }");

  if (!isDefault("blurEnabled", appearance.blurEnabled))
    blur.push("enabled = " + luaBool(appearance.blurEnabled));
  if (!isDefault("blurSize", appearance.blurSize))
    blur.push("size = " + luaNum(appearance.blurSize));
  if (!isDefault("blurPasses", appearance.blurPasses))
    blur.push("passes = " + luaNum(appearance.blurPasses));
  if (!isDefault("blurXray", appearance.blurXray))
    blur.push("xray = " + luaBool(appearance.blurXray));
  if (blur.length)
    decoration.push("blur = {\n      " + blur.join(",\n      ") + ",\n    }");

  if (!isDefault("animationsEnabled", appearance.animationsEnabled))
    animations.push("enabled = " + luaBool(appearance.animationsEnabled));

  var groups = [];
  if (general.length)
    groups.push("  general = {\n    " + general.join(",\n    ") + ",\n  }");
  if (decoration.length)
    groups.push("  decoration = {\n    " + decoration.join(",\n    ") + ",\n  }");
  if (animations.length)
    groups.push("  animations = {\n    " + animations.join(",\n    ") + ",\n  }");

  if (!groups.length)
    return "";

  return "hl.config({\n" + groups.join(",\n") + ",\n})\n";
}

// -----------------------------------------------------
function genEnvVars(envVars) {
  if (!envVars || !envVars.length)
    return "";
  var lines = envVars
    .filter(function (e) { return e && e.name; })
    .map(function (e) { return "hl.env(" + luaStr(e.name) + ", " + luaStr(e.value) + ")"; });
  return lines.length ? lines.join("\n") + "\n" : "";
}

// -----------------------------------------------------
function genAutostart(autostart) {
  var entries = (autostart || []).filter(function (e) { return e && e.command && e.enabled !== false; });
  if (!entries.length)
    return "";
  var body = entries.map(function (e) { return "  hl.exec_cmd(" + luaStr(e.command) + ")"; }).join("\n");
  return 'hl.on("hyprland.start", function()\n' + body + "\nend)\n";
}

// -----------------------------------------------------
// windowRules: [{ name, match: {class, title, xwayland, float, fullscreen, pin}, action, value }]
// action is one of the boolean-ish flags (float, pin, center, no_focus,
// no_screen_share, suppress_event...) or a value-carrying one (move, workspace,
// opacity, rounding) — value is only emitted when the action expects one.
var WINDOW_RULE_VALUE_ACTIONS = { move: true, workspace: true, opacity: true, rounding: true, size: true, monitor: true, tag: true };

function genWindowRules(windowRules) {
  var entries = (windowRules || []).filter(function (r) { return r && r.action; });
  if (!entries.length)
    return "";
  return entries.map(function (r, i) {
    var match = [];
    if (r.match) {
      Object.keys(r.match).forEach(function (k) {
        var v = r.match[k];
        if (v === undefined || v === null || v === "")
          return;
        match.push(k + " = " + (typeof v === "boolean" ? luaBool(v) : luaStr(v)));
      });
    }
    var fields = ["name = " + luaStr(r.name || ("hydra-shell-custom-" + i))];
    if (match.length)
      fields.push("match = { " + match.join(", ") + " }");
    if (WINDOW_RULE_VALUE_ACTIONS[r.action])
      fields.push(r.action + " = " + luaStr(r.value));
    else
      fields.push(r.action + " = true");
    return "hl.window_rule({\n  " + fields.join(",\n  ") + ",\n})";
  }).join("\n\n") + "\n";
}

// -----------------------------------------------------
// layerRules: [{ name, namespace, action, value }]
var LAYER_RULE_VALUE_ACTIONS = { ignore_alpha: true, order: true, above_lock: true, animation: true };

function genLayerRules(layerRules) {
  var entries = (layerRules || []).filter(function (r) { return r && r.namespace && r.action; });
  if (!entries.length)
    return "";
  return entries.map(function (r, i) {
    var fields = [
      "name = " + luaStr(r.name || ("hydra-shell-layer-" + i)),
      "match = { namespace = " + luaStr(r.namespace) + " }"
    ];
    if (LAYER_RULE_VALUE_ACTIONS[r.action])
      fields.push(r.action + " = " + (r.action === "order" || r.action === "above_lock" ? luaNum(r.value) : luaStr(r.value)));
    else
      fields.push(r.action + " = true");
    return "hl.layer_rule({\n  " + fields.join(",\n  ") + ",\n})";
  }).join("\n\n") + "\n";
}

// -----------------------------------------------------
// animCurves: [{ name, x0, y0, x1, y1 }], animItems: [{ leaf, enabled, speed, bezier, style }]
function genAnimations(animCurves, animItems) {
  var lines = [];
  (animCurves || []).forEach(function (c) {
    if (!c || !c.name)
      return;
    var pts = "{ { " + luaNum(c.x0) + ", " + luaNum(c.y0) + " }, { " + luaNum(c.x1) + ", " + luaNum(c.y1) + " } }";
    lines.push("hl.curve(" + luaStr(c.name) + ', { type = "bezier", points = ' + pts + " })");
  });
  (animItems || []).forEach(function (a) {
    if (!a || !a.leaf)
      return;
    var fields = ["leaf = " + luaStr(a.leaf), "enabled = " + luaBool(a.enabled !== false)];
    if (a.speed !== undefined)
      fields.push("speed = " + luaNum(a.speed));
    if (a.bezier)
      fields.push("bezier = " + luaStr(a.bezier));
    if (a.style)
      fields.push("style = " + luaStr(a.style));
    lines.push("hl.animation({ " + fields.join(", ") + " })");
  });
  return lines.length ? lines.join("\n") + "\n" : "";
}

// -----------------------------------------------------
// keybinds: [{ combo, command, description }] — custom ADDED binds. Distinct
// from rebinds (see genRebinds): these register a new chord, they don't
// remap a shipped one.
function genKeybinds(keybinds) {
  var entries = (keybinds || []).filter(function (k) { return k && k.combo && k.command; });
  if (!entries.length)
    return "";
  return entries.map(function (k) {
    var opts = k.description ? ", { description = " + luaStr(k.description) + " }" : "";
    return "hl.bind(" + luaStr(k.combo) + ", hl.dsp.exec_cmd(" + luaStr(k.command) + ")" + opts + ")";
  }).join("\n") + "\n";
}

// -----------------------------------------------------
// rebinds: { "SUPER + T": "SUPER + Y" } -> ~/.config/hypr/hydra-shell/rebinds.lua
// Always writes a full `return {}` (even empty) — see modules/binds.lua's
// K() helper and the note on writeRebindsLua in ryoku-arch's hypr.go: leaving
// a stale entry on disk if the map ever becomes empty would silently keep an
// old remap alive.
function buildRebindsLua(rebinds) {
  rebinds = rebinds || {};
  var keys = Object.keys(rebinds).filter(function (k) { return rebinds[k] && rebinds[k] !== k; });
  var header = "-- Generated by hydra-shell Settings (Hyprland \u2192 Atalhos). Do not edit by hand.\n";
  if (!keys.length)
    return header + "return {}\n";
  var lines = keys.map(function (k) { return "  [" + luaStr(k) + "] = " + luaStr(rebinds[k]) + ","; });
  return header + "return {\n" + lines.join("\n") + "\n}\n";
}

// -----------------------------------------------------
// Orchestrator for ~/.config/hypr/hydra-shell/settings.lua. Section order is
// deliberate: appearance/env/animations/rules/keybinds first, autostart last
// — an exec command should see every other override already in effect
// (mirrors hyprmod/core/config.py's documented section order, and
// Assets/Hyprland/hyprland.lua's own require chain).
function buildSettingsLua(hyprland) {
  hyprland = hyprland || {};
  var sections = [
    genEnvVars(hyprland.envVars),
    genAppearance(hyprland.appearance),
    genAnimations(hyprland.animCurves, hyprland.animItems),
    genWindowRules(hyprland.windowRules),
    genLayerRules(hyprland.layerRules),
    genKeybinds(hyprland.keybinds),
    genAutostart(hyprland.autostart)
  ].filter(function (s) { return s && s.length; });

  var header = "-- Generated by hydra-shell Settings (Hyprland tab). Do not edit by hand \u2014\n" +
    "-- your changes will be overwritten on the next Save. Use ~/.config/hypr/user.lua\n" +
    "-- for hand-written overrides instead.\n";

  if (!sections.length)
    return header;

  return header + "\n" + sections.join("\n");
}
