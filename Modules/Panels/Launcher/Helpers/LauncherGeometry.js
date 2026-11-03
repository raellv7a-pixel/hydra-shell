.pragma library

function panelWidth(screenWidth, scale, inset, density, catalog) {
  const available = Math.max(1, screenWidth - inset * 2);
  const ratio = density === "compact" ? 0.88 : (density === "comfortable" ? 1.08 : 1);
  const target = catalog ? Math.max(1060 * scale, screenWidth * 0.86) : Math.max(860 * scale, screenWidth * 0.66);
  return Math.round(Math.min(available, (catalog ? 1400 : 1060) * scale * ratio, target * ratio));
}

function panelHeight(screenHeight, scale, inset, homeHeight, density) {
  const ratio = density === "compact" ? 0.90 : (density === "comfortable" ? 1.06 : 1);
  const available = Math.min(Math.max(1, screenHeight - inset * 2), 980 * scale * ratio, screenHeight * (homeHeight > 0 ? 0.94 : 0.88));
  return Math.round(homeHeight > 0 ? Math.min(homeHeight, available) : available);
}
