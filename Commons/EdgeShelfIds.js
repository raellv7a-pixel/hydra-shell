.pragma library

/**
 * Derives a normalized Umbriel named scratchpad name for an Edge Shelf app.
 * Matches python Scripts/python/umbriel_keybinds.py::app_id_to_scratchpad_name exactly.
 *
 * Rules:
 * 1. String(appId).toLowerCase().trim()
 * 2. If ends with ".desktop", strip ".desktop"
 * 3. Replace any sequence of non-[a-z0-9_-] with a single "-"
 * 4. Strip leading and trailing hyphens
 * 5. Return "hydra-edge-" + slug if slug not empty, else "hydra-edge-app"
 */
function appIdToScratchpadName(appId) {
  var slug = String(appId || "").toLowerCase().trim();
  if (slug.endsWith(".desktop")) {
    slug = slug.slice(0, -8);
  }
  slug = slug.replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
  return slug.length > 0 ? ("hydra-edge-" + slug) : "hydra-edge-app";
}

/**
 * Normalizes an app ID by trimming, lowercasing, and stripping .desktop suffix.
 */
function normalizeAppId(appId) {
  var s = String(appId || "").toLowerCase().trim();
  if (s.endsWith(".desktop")) {
    s = s.slice(0, -8);
  }
  return s;
}
