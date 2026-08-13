pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI

Singleton {
  id: root

  // Suppresses the onDarkModeChanged auto-regenerate reaction while smart mode
  // itself is writing the resolved darkMode — that write is already followed by
  // a generation call further down the same code path, so reacting to it too
  // would spawn a redundant, duplicate generation pass.
  property bool _applyingSmartDecision: false

  Connections {
    target: WallpaperService

    // When the wallpaper changes, regenerate theme if necessary
    function onWallpaperChanged(screenName, path) {
      var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
      if (effectiveMonitor === "" || effectiveMonitor === undefined) {
        effectiveMonitor = Screen.name;
      }

      if (screenName !== effectiveMonitor)
        return;

      // Smart mode: decide dark/light from the new wallpaper's luminance before
      // regenerating, regardless of whether colors come from the wallpaper or a
      // predefined scheme — schedulingMode is "how to decide the mode", which is
      // orthogonal to "where colors come from" (same as "manual"/"location").
      if (Settings.data.colorSchemes.schedulingMode === "wallpaper") {
        const wp = WallpaperService.getWallpaper(effectiveMonitor);
        if (wp) {
          TemplateProcessor.previewWallpaperPalette(wp, TemplateProcessor.getSchemeType(), function (result) {
            if (result && result.recommendedMode) {
              root._applyingSmartDecision = true;
              Settings.data.colorSchemes.darkMode = (result.recommendedMode === "dark");
              root._applyingSmartDecision = false;
            }
            root._continueAfterWallpaperChanged();
          });
          return;
        }
      }

      root._continueAfterWallpaperChanged();
    }
  }

  function _continueAfterWallpaperChanged() {
    if (Settings.data.colorSchemes.useWallpaperColors) {
      generateFromWallpaper();
    } else if (ColorSchemeService.lastPredefinedSchemeData) {
      // Regenerate templates only; skip applyScheme so colors.json and scheme reload stay untouched
      // when outputs are unchanged (see template processor skip-identical writes).
      generateFromPredefinedScheme(ColorSchemeService.lastPredefinedSchemeData);
    } else {
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
    }
  }

  Connections {
    target: Settings.data.colorSchemes
    function onDarkModeChanged() {
      if (root._applyingSmartDecision)
        return;
      Logger.d("AppThemeService", "Detected dark mode change");
      generate();
    }
    function onMonitorForColorsChanged() {
      if (Settings.data.colorSchemes.useWallpaperColors) {
        Logger.d("AppThemeService", "Monitor for colors changed to:", Settings.data.colorSchemes.monitorForColors);
        generateFromWallpaper();
      }
    }
    function onGenerationMethodChanged() {
      Logger.d("AppThemeService", "Generation method changed to:", Settings.data.colorSchemes.generationMethod);
      generate();
    }
  }

  // PUBLIC FUNCTIONS
  function init() {
    Logger.i("AppThemeService", "Service started");

    // Recover users who already enabled the papirusFolders template before
    // the one-time sudo grant existed (or on a machine where it never ran) —
    // don't make them re-toggle the setting to get it working.
    const activeTemplates = Settings.data.templates.activeTemplates || [];
    for (let i = 0; i < activeTemplates.length; i++) {
      if (activeTemplates[i].id === "papirusFolders" && activeTemplates[i].enabled) {
        PapirusFoldersSetupService.ensureConfigured();
        break;
      }
    }
  }

  function generate() {
    if (Settings.data.colorSchemes.useWallpaperColors) {
      generateFromWallpaper();
    } else {
      // applyScheme will trigger template generation via schemeReader.onLoaded
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
    }
  }

  function generateFromWallpaper() {
    var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }

    const wp = WallpaperService.getWallpaper(effectiveMonitor);
    if (!wp) {
      Logger.e("AppThemeService", "No wallpaper found for monitor:", effectiveMonitor);
      return;
    }
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    TemplateProcessor.processWallpaperColors(wp, mode);
  }

  function generateFromPredefinedScheme(schemeData) {
    Logger.i("AppThemeService", "Generating templates from predefined color scheme");
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }
    const wallpaperPath = WallpaperService.getWallpaper(effectiveMonitor) || "";
    TemplateProcessor.processPredefinedScheme(schemeData, mode, wallpaperPath);
  }
}
