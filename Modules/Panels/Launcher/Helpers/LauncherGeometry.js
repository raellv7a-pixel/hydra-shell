.pragma library

function panelWidth(screenWidth, scale, inset, density) {
  const available = Math.max(1, screenWidth - inset * 2);
  const ratio = density === "compact" ? 0.88 : (density === "comfortable" ? 1.08 : 1);
  return Math.round(Math.min(available, 960 * scale * ratio, Math.max(740 * scale * ratio, screenWidth * 0.55 * ratio)));
}

function panelHeight(screenHeight, scale, inset, homeHeight, density) {
  const ratio = density === "compact" ? 0.90 : (density === "comfortable" ? 1.06 : 1);
  const available = Math.min(Math.max(1, screenHeight - inset * 2), 740 * scale * ratio, screenHeight * 0.80);
  return Math.round(homeHeight > 0 ? Math.min(homeHeight, available) : available);
}
