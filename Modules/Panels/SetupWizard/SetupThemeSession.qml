import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Theming
import qs.Services.UI

Item {
  id: root

  property bool busy: false
  property string error: ""
  property bool wallpaperAvailable: false

  signal committed()
  signal failed(string message)
  signal wallpaperUnavailable()

  property bool _commitAttempted: false
  property bool _pendingCancel: false
  property var _snapshotColors: null
  property var _snapshotSettings: null
  property int _previewGeneration: 0
  property bool _pendingCommit: false
  property string _commitScheme: ""
  property bool _commitDark: true
  signal cancelled()
  property bool _commitWallpaper: false
  property string _commitSpec: ""
  property bool _colorsSaved: false
  property bool _templatesSaved: false
  property bool _awaitTemplates: false

  Component.onCompleted: {
    checkWallpaperAvailability();
  }

  function checkWallpaperAvailability() {
    const effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    const wp = WallpaperService.getWallpaper(effectiveMonitor) || "";
    wallpaperAvailable = (wp !== "" && !WallpaperService.isSolidColorPath(wp));
    return wallpaperAvailable;
  }

  function begin() {
    _snapshotColors = Color.takeSnapshot();
    _snapshotSettings = {
      darkMode: Settings.data.colorSchemes.darkMode,
      useWallpaperColors: Settings.data.colorSchemes.useWallpaperColors,
      predefinedScheme: Settings.data.colorSchemes.predefinedScheme,
      materialSpec: Settings.data.colorSchemes.materialSpec
    };
    _commitAttempted = false;
    _pendingCancel = false;
    error = "";
    checkWallpaperAvailability();
  }

  function restoreSnapshots() {
    AppThemeService.recipeUpdateInProgress = true;
    try {
      if (_snapshotSettings) {
        Settings.data.colorSchemes.darkMode = _snapshotSettings.darkMode;
        Settings.data.colorSchemes.useWallpaperColors = _snapshotSettings.useWallpaperColors;
        Settings.data.colorSchemes.predefinedScheme = _snapshotSettings.predefinedScheme;
        Settings.data.colorSchemes.materialSpec = _snapshotSettings.materialSpec;
      }
    } finally {
      AppThemeService.recipeUpdateInProgress = false;
    }
    if (_snapshotColors)
      Color.applySnapshot(_snapshotColors);
  }

  function finalize() {
    _snapshotColors = null;
    _snapshotSettings = null;
    _commitAttempted = false;
    _pendingCancel = false;
    Color.commitPreview();
    ColorSchemeService.pushSystemColorScheme();
  }

  function cancel() {
    if (busy && _pendingCommit)
      return false;
    _previewGeneration++;
    busy = false;
    error = "";
    previewSchemeReader.path = "";
    restoreSnapshots();
    // A failed final settings write may follow a successful theme write.
    // Restore through the same official pipeline before acknowledging Cancel.
    if (_commitAttempted && _snapshotSettings) {
      _pendingCancel = true;
      commit(_snapshotSettings.predefinedScheme, _snapshotSettings.darkMode,
             _snapshotSettings.useWallpaperColors, _snapshotSettings.materialSpec);
      return false;
    }
    Color.clearPreview();
    _snapshotColors = null;
    _snapshotSettings = null;
    _pendingCancel = false;
    return true;
  }

  function previewScheme(name, dark) {
    const gen = ++_previewGeneration;
    error = "";
    busy = true;

    const path = ColorSchemeService.resolveSchemePath(name);
    if (!path) {
      busy = false;
      error = I18n.tr("setup.hydra.theme.scheme-not-found");
      failed(error);
      return;
    }

    previewSchemeReader.targetDark = dark;
    previewSchemeReader.targetGeneration = gen;
    previewSchemeReader.path = "";
    previewSchemeReader.path = path;
  }

  FileView {
    id: previewSchemeReader
    property bool targetDark: true
    property int targetGeneration: 0

    onLoaded: {
      if (targetGeneration !== root._previewGeneration)
        return;
      try {
        const data = JSON.parse(text());
        let variant = data;
        if (data && (data.dark || data.light)) {
          variant = targetDark ? (data.dark || data.light) : (data.light || data.dark);
        }
        if (variant) {
          Color.previewDarkMode = targetDark;
          Color.previewPalette(variant);
        }
        root.busy = false;
      } catch (e) {
        if (targetGeneration === root._previewGeneration) {
          root.busy = false;
          root.error = String(e);
        }
      }
    }

    onLoadFailed: error => {
      if (targetGeneration === root._previewGeneration) {
        root.busy = false;
        root.error = String(error);
      }
    }
  }

  function previewWallpaper(dark) {
    const gen = ++_previewGeneration;
    error = "";
    checkWallpaperAvailability();
    const effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    const wp = WallpaperService.getWallpaper(effectiveMonitor) || "";

    if (!wp || WallpaperService.isSolidColorPath(wp)) {
      wallpaperAvailable = false;
      busy = false;
      error = I18n.tr("setup.hydra.theme.wallpaper-unavailable");
      // Nonfatal fallback notification
      wallpaperUnavailable();
      return;
    }

    busy = true;
    const recipe = TemplateProcessor.getRecipe();
    TemplateProcessor.previewWallpaperPalette(wp, recipe, function(result) {
      if (gen !== root._previewGeneration)
        return;
      root.busy = false;
      if (!result) {
        root.wallpaperAvailable = false;
        root.error = I18n.tr("setup.hydra.theme.wallpaper-preview-failed");
        root.wallpaperUnavailable();
        return;
      }
      root.wallpaperAvailable = true;
      const rawMode = dark ? (result.dark || result.light) : (result.light || result.dark);
      const mapped = TemplateProcessor.mapToColorKeys(rawMode);
      if (mapped) {
        Color.previewDarkMode = dark;
        Color.previewPalette(mapped);
      }
    });
  }

  function commit(name, dark, useWallpaperColors, materialSpec) {
    if (busy && _pendingCommit)
      return;

    error = "";
    busy = true;
    _pendingCommit = true;
    _commitAttempted = true;
    _commitScheme = name || "Hydra Glacier";
    _commitDark = !!dark;
    _commitWallpaper = !!useWallpaperColors;
    _commitSpec = materialSpec || Settings.data.colorSchemes.materialSpec || "2025";

    // If wallpaper mode is requested but unavailable, normalize fallback to preset
    if (_commitWallpaper) {
      const effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
      const wp = WallpaperService.getWallpaper(effectiveMonitor) || "";
      if (!wp || WallpaperService.isSolidColorPath(wp)) {
        _commitWallpaper = false;
        wallpaperAvailable = false;
        wallpaperUnavailable();
      }
    }

    _colorsSaved = _commitWallpaper;
    _awaitTemplates = _commitWallpaper || ColorSchemeService.hasEnabledTemplates() || Settings.data.templates.enableUserTheming;
    _templatesSaved = !_awaitTemplates;
    // Use the existing recipe guard to stage a coherent selection without
    // dark/spec reactions spawning a second pipeline with the old scheme.
    AppThemeService.recipeUpdateInProgress = true;
    try {
      Settings.data.colorSchemes.darkMode = _commitDark;
      Settings.data.colorSchemes.useWallpaperColors = _commitWallpaper;
      Settings.data.colorSchemes.materialSpec = _commitSpec;
      if (!_commitWallpaper)
        Settings.data.colorSchemes.predefinedScheme = ColorSchemeService.getBasename(_commitScheme);
    } finally {
      AppThemeService.recipeUpdateInProgress = false;
    }
    if (_commitWallpaper)
      AppThemeService.generateFromWallpaper();
    else
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
  }

  function _handleSuccess() {
    if (!root._pendingCommit || !_colorsSaved || !_templatesSaved)
      return;
    root._pendingCommit = false;
    root.busy = false;
    if (_pendingCancel) {
      finalize();
      root.cancelled();
    } else {
      // Final settings acknowledgment, not palette I/O, accepts the session.
      root.committed();
    }
  }

  function _handleFailure(errorMsg) {
    if (!root._pendingCommit)
      return;
    root._pendingCommit = false;
    root.busy = false;
    root.error = errorMsg;
    restoreSnapshots();
    root.failed(errorMsg);
  }

  Connections {
    target: ColorSchemeService
    function onColorsWritten() {
      if (root._pendingCommit && !root._commitWallpaper) {
        root._colorsSaved = true;
        root._handleSuccess();
      }
    }
    function onColorsWriteFailed(errorMsg) {
      if (root._pendingCommit && !root._commitWallpaper) {
        root._handleFailure(errorMsg);
      }
    }
  }

  Connections {
    target: TemplateProcessor
    function onColorsGenerated() {
      if (root._pendingCommit && root._awaitTemplates) {
        root._templatesSaved = true;
        root._handleSuccess();
      }
    }
    function onColorsGenerationFailed(message) {
      if (root._pendingCommit && root._awaitTemplates)
        root._handleFailure(I18n.tr("setup.hydra.theme.generation-failed", { error: message }));
    }
  }
}
