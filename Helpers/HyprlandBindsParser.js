// -----------------------------------------------------
// Reads `hyprctl binds -j` into a legend of shipped/described keybinds, for
// the Hyprland tab's Atalhos sub-tab (PLANO_INTEGRACAO_HYPRMOD.md §5.1).
//
// Pivot from the plan's original idea (port ryoku-arch's text parser for
// modules/binds.lua): unnecessary. Hyprland's own `hyprctl binds -j` already
// reports modmask + key + description per bind — introspection over IPC,
// not text-parsing a Lua file we'd have to keep a matching regex for. This
// is also strictly MORE robust than a text parser: it reflects binds.lua's
// live k-value (post K() rebind resolution is NOT visible here, since K()
// resolves before hl.bind() ever registers — see the caveat on decode()).
//
// Confirmed against a live Hyprland 0.56.2 instance during development:
// modmask is a bitmask — SHIFT=1, CAPS=2, CTRL=4, ALT=8, NUMLOCK=16, MOD3=32,
// SUPER=64, MOD5=128 (verified: SUPER+SHIFT combos report modmask 65,
// SUPER+ALT combos report 72).
var MOD_BITS = [
  { bit: 64, name: "SUPER" },
  { bit: 4, name: "CTRL" },
  { bit: 8, name: "ALT" },
  { bit: 1, name: "SHIFT" }
];

function decodeModmask(modmask) {
  var mods = [];
  for (var i = 0; i < MOD_BITS.length; i++) {
    if ((modmask & MOD_BITS[i].bit) !== 0) {
      mods.push(MOD_BITS[i].name);
    }
  }
  return mods;
}

// Matches the "MOD + MOD + Key" convention used throughout
// Assets/Hyprland/modules/binds.lua (space-padded, `+`-joined) — this is
// also exactly the string shape hl.bind()/hl.unbind() expect as their first
// argument, so a combo string from here is directly usable in a generated
// `hl.unbind(...); hl.bind(...)` pair.
function comboString(bind) {
  var mods = decodeModmask(bind.modmask || 0);
  var parts = mods.concat([bind.key]);
  return parts.join(" + ");
}

// Returns [{ combo, description, locked, repeating, mouse }], one entry per
// *described* bind (has_description === true) — undescribed entries are
// noise (Hyprland's own submap-internal bookkeeping binds, plugin binds that
// don't set a description, etc.), not something a rebind UI should offer.
//
// Caveat: if a shipped bind was already remapped via hydra-shell/rebinds.lua
// (K() applied before hl.bind() ran), `combo` here is the CURRENT
// (already-remapped) chord, not the original shipped one — correct for "what
// key does this action currently answer to", which is what the UI needs to
// display; matching it back to a rebinds.lua key is the caller's job (see
// AtalhosSubTab.qml's originalCombo lookup against draft.rebinds).
function parseBindsJson(rawJson) {
  var data;
  try {
    data = JSON.parse(rawJson || "[]");
  } catch (e) {
    return [];
  }
  var out = [];
  for (var i = 0; i < data.length; i++) {
    var b = data[i];
    if (!b || !b.has_description || !b.description)
      continue;
    if (b.submap && b.submap.length > 0)
      continue; // submap-local binds (e.g. the resize mode) aren't top-level rebind targets
    out.push({
      "combo": comboString(b),
      "description": b.description,
      "locked": !!b.locked,
      "repeating": !!b.repeat,
      "mouse": !!b.mouse
    });
  }
  return out;
}
