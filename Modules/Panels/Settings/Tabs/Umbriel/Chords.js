.pragma library

const MODS = { mod: "Mod", super: "Mod", logo: "Mod", win: "Mod", ctrl: "Ctrl", control: "Ctrl", alt: "Alt", shift: "Shift" };
const KEYS = { esc: "Escape", escape: "Escape", enter: "Return", return: "Return", space: "Space", comma: "Comma", period: "Period", print: "Print", left: "Left", right: "Right", up: "Up", down: "Down", tab: "Tab", backspace: "BackSpace", delete: "Delete", home: "Home", end: "End", insert: "Insert", pageup: "Prior", pagedown: "Next", prior: "Prior", next: "Next", wheelup: "WheelUp", wheeldown: "WheelDown", wheelleft: "WheelLeft", wheelright: "WheelRight", mouseleft: "MouseLeft", mouseright: "MouseRight", mousemiddle: "MouseMiddle", mouseback: "MouseBack", mouseforward: "MouseForward" };

function normalize(value) {
  const parts = String(value || "").split("+").map(s => s.trim());
  if (parts.some(s => !s)) return "";
  let mods = {};
  let keys = [];
  for (const part of parts) {
    const key = part.toLowerCase();
    if (MODS[key]) mods[MODS[key]] = true;
    else if (/^[a-z0-9]$/.test(key)) keys.push(key.toUpperCase());
    else if (/^f(?:[1-9]|1[0-9]|2[0-4])$/.test(key)) keys.push(key.toUpperCase());
    else if (KEYS[key]) keys.push(KEYS[key]);
    else if (/^xf86[a-z0-9]+$/.test(key)) keys.push(key);
    else return "";
  }
  if (keys.length !== 1 || (/^(Wheel|Mouse)/.test(keys[0]) && !Object.keys(mods).length)) return "";
  return ["Mod", "Ctrl", "Alt", "Shift"].filter(m => mods[m]).concat(keys).join("+");
}

function conflicts(rows) {
  let seen = {};
  let result = {};
  for (const row of rows) {
    const normalized = normalize(row.chord);
    if (!normalized) continue;
    if (seen[normalized]) {
      result[row.id] = seen[normalized].label;
      result[seen[normalized].id] = row.label;
    } else seen[normalized] = row;
  }
  return result;
}

function keyName(event) {
  const key = event.key;
  if (key >= Qt.Key_A && key <= Qt.Key_Z || key >= Qt.Key_0 && key <= Qt.Key_9)
    return String.fromCharCode(key);
  if (key >= Qt.Key_F1 && key <= Qt.Key_F24)
    return "F" + (key - Qt.Key_F1 + 1);
  const map = {};
  map[Qt.Key_Escape] = "Escape";
  map[Qt.Key_Return] = "Return";
  map[Qt.Key_Enter] = "Return";
  map[Qt.Key_Space] = "Space";
  map[Qt.Key_Tab] = "Tab";
  map[Qt.Key_Left] = "Left";
  map[Qt.Key_Right] = "Right";
  map[Qt.Key_Up] = "Up";
  map[Qt.Key_Down] = "Down";
  map[Qt.Key_Print] = "Print";
  map[Qt.Key_Backspace] = "BackSpace";
  map[Qt.Key_Delete] = "Delete";
  map[Qt.Key_Home] = "Home";
  map[Qt.Key_End] = "End";
  map[Qt.Key_Insert] = "Insert";
  map[Qt.Key_PageUp] = "Prior";
  map[Qt.Key_PageDown] = "Next";
  map[Qt.Key_Comma] = "Comma";
  map[Qt.Key_Period] = "Period";
  return map[key] || "";
}

function fromEvent(event) {
  const key = keyName(event);
  if (!key) return "";
  let mods = [];
  if (event.modifiers & Qt.MetaModifier) mods.push("Mod");
  if (event.modifiers & Qt.ControlModifier) mods.push("Ctrl");
  if (event.modifiers & Qt.AltModifier) mods.push("Alt");
  if (event.modifiers & Qt.ShiftModifier) mods.push("Shift");
  return mods.concat(key).join("+");
}
