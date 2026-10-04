.pragma library

// Umbriel publishes commands, not portal/session state or applied-target acknowledgements.
function empty() {
  return {serial: -1, mode: "unknown", targetKind: "none", targetValue: ""};
}
function reduce(previous, data) {
  if (!data || !Number.isSafeInteger(data.serial) || data.serial < 0 || data.serial <= previous.serial)
    return previous;
  const modes = {window: "manual", output: "manual", follow_window: "follow-window", follow_output: "follow-output", follow_stop: "manual", clear: "cleared"};
  if (!Object.prototype.hasOwnProperty.call(modes, data.kind)) return previous;
  if ((data.kind === "window" && typeof data.identifier !== "string") || (data.kind === "output" && typeof data.output !== "string")) return previous;
  return {
    serial: data.serial,
    mode: data.serial === 0 ? "unknown" : modes[data.kind],
    targetKind: data.kind === "window" ? "window" : data.kind === "output" ? "output" : "none",
    targetValue: data.kind === "window" ? data.identifier : data.kind === "output" ? data.output : ""
  };
}
