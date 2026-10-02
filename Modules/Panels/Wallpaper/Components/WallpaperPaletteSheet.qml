import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property string wallpaperPath: ""
  property string screenName: ""
  property var screen
  property var editingScheme: null
  property string editingVariant: "dark"
  property string pickerTargetKey: ""
  property bool previewActive: false
  property bool saving: false
  property var originalColors: null
  property string draftModel: Settings.data.colorSchemes.generationMethod
  property string draftSurfaceStyle: Settings.data.colorSchemes.surfaceStyle
  property int draftSeedIndex: Settings.data.colorSchemes.seedIndex
  property string draftMaterialSpec: TemplateProcessor.getMaterialSpec()
  property string effectiveMaterialSpec: ""
  property var candidates: []
  property var generatedScheme: null
  property string effectiveModel: ""
  property bool generating: false
  property string generationError: ""
  property bool manualEdits: false
  property bool ready: false
  property bool acceptingResult: false
  property int generationRevision: 0
  property var pendingPreview: null
  property var diskColors: null
  property int wallpaperRevision: 0
  readonly property bool materialRecipe: TemplateProcessor.materialSchemeKeys.includes(draftModel)
  readonly property bool activeColorSource: {
    // currentWallpapers entries mutate in place; wallpaperChanged invalidates this lookup.
    const revision = wallpaperRevision;
    return Settings.data.colorSchemes.useWallpaperColors && wallpaperPath !== "" && Settings.preprocessPath(wallpaperPath) === Settings.preprocessPath(WallpaperService.getWallpaper(Settings.data.colorSchemes.monitorForColors || Screen.name));
  }

  readonly property var colorRoles: [
    {
      key: "mPrimary",
      labelKey: "primary"
    },
    {
      key: "mOnPrimary",
      labelKey: "on-primary"
    },
    {
      key: "mSecondary",
      labelKey: "secondary"
    },
    {
      key: "mOnSecondary",
      labelKey: "on-secondary"
    },
    {
      key: "mTertiary",
      labelKey: "tertiary"
    },
    {
      key: "mOnTertiary",
      labelKey: "on-tertiary"
    },
    {
      key: "mError",
      labelKey: "error"
    },
    {
      key: "mOnError",
      labelKey: "on-error"
    },
    {
      key: "mSurface",
      labelKey: "surface"
    },
    {
      key: "mOnSurface",
      labelKey: "on-surface"
    },
    {
      key: "mSurfaceVariant",
      labelKey: "surface-variant"
    },
    {
      key: "mOnSurfaceVariant",
      labelKey: "on-surface-variant"
    },
    {
      key: "mOutline",
      labelKey: "outline"
    },
    {
      key: "mShadow",
      labelKey: "shadow"
    },
    {
      key: "mHover",
      labelKey: "hover"
    },
    {
      key: "mOnHover",
      labelKey: "on-hover"
    }
  ]

  Component.onCompleted: {
    ready = true;
    seedEditor();
  }
  Component.onDestruction: {
    stopPreview();
    cancelGeneration();
  }
  onVisibleChanged: {
    if (!visible) {
      stopPreview();
      cancelGeneration();
    } else if (ready)
      regenerate();
  }
  onWallpaperPathChanged: {
    candidates = [];
    if (ready)
      regenerate();
  }

  Connections {
    target: WallpaperService
    function onWallpaperChanged() {
      root.wallpaperRevision++;
    }
  }
  onDraftModelChanged: {
    if (ready)
      regenerate();
  }
  onDraftMaterialSpecChanged: {
    if (ready)
      regenerate();
  }
  onDraftSurfaceStyleChanged: {
    if (ready)
      regenerate();
  }
  onDraftSeedIndexChanged: {
    if (ready && !acceptingResult)
      regenerate();
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function activeColors() {
    if (diskColors)
      return clone(diskColors);
    var colors = {};
    for (const key of Object.keys(TemplateProcessor.colorKeyMap))
      colors[key] = Color[key].toString();
    return colors;
  }

  function fallbackScheme() {
    const colors = activeColors();
    return {
      dark: colors,
      light: clone(colors)
    };
  }

  function seedEditor() {
    stopPreview();
    editingVariant = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    schemeNameInput.text = "";
    if (wallpaperPath !== "") {
      regenerate();
      return;
    }
    const schemeName = Settings.data.colorSchemes.predefinedScheme;
    if (!Settings.data.colorSchemes.useWallpaperColors && schemeName) {
      const path = ColorSchemeService.resolveSchemePath(schemeName);
      if (path) {
        schemeFileReader.path = "";
        schemeFileReader.path = path;
        return;
      }
    }
    editingScheme = fallbackScheme();
  }

  function cancelGeneration() {
    generationRevision++;
    generationDebounce.stop();
    if (pendingPreview) {
      pendingPreview.callback = null;
      pendingPreview.running = false;
      pendingPreview = null;
    }
    generating = false;
  }

  function regenerate() {
    stopPreview();
    cancelGeneration();
    editingScheme = null;
    generatedScheme = null;
    manualEdits = false;
    generationError = "";
    if (!ready || !visible)
      return;
    if (!wallpaperPath.startsWith("/")) {
      generationError = I18n.tr("wallpaper.palette.local-required");
      return;
    }
    generating = true;
    generationDebounce.restart();
  }

  function generateContextualPalette() {
    const revision = generationRevision;
    const recipe = {
      generationMethod: draftModel,
      seedIndex: draftSeedIndex,
      surfaceStyle: draftSurfaceStyle,
      materialSpec: draftMaterialSpec
    };
    pendingPreview = TemplateProcessor.previewWallpaperPalette(wallpaperPath, recipe, function (result) {
      if (!root || revision !== root.generationRevision)
        return;
      root.pendingPreview = null;
      root.generating = false;
      if (!result || !result.dark || !result.light) {
        root.generationError = I18n.tr("wallpaper.palette.load-error");
        return;
      }
      root.acceptingResult = true;
      root.draftSeedIndex = result.seedIndex;
      root.acceptingResult = false;
      root.candidates = result.candidates;
      root.effectiveModel = result.effectiveModel;
      root.effectiveMaterialSpec = result.effectiveMaterialSpec || "";
      root.generatedScheme = {
        dark: TemplateProcessor.mapToColorKeys(result.dark),
        light: TemplateProcessor.mapToColorKeys(result.light)
      };
      root.editingScheme = root.clone(root.generatedScheme);
    });
  }

  function resetEditor() {
    stopPreview();
    manualEdits = false;
    if (generatedScheme)
      editingScheme = clone(generatedScheme);
    else
      seedEditor();
  }

  function syncRecipe() {
    if (AppThemeService.recipeUpdateInProgress)
      return;
    draftModel = Settings.data.colorSchemes.generationMethod;
    draftSurfaceStyle = Settings.data.colorSchemes.surfaceStyle;
    draftSeedIndex = Settings.data.colorSchemes.seedIndex;
    draftMaterialSpec = TemplateProcessor.getMaterialSpec();
  }

  function applyRecipe() {
    if (!activeColorSource || generating || !editingScheme)
      return;
    stopPreview();
    const recipe = {
      generationMethod: draftModel,
      surfaceStyle: draftSurfaceStyle,
      seedIndex: draftSeedIndex,
      materialSpec: draftMaterialSpec
    };
    AppThemeService.recipeUpdateInProgress = true;
    try {
      Settings.data.colorSchemes.generationMethod = recipe.generationMethod;
      Settings.data.colorSchemes.surfaceStyle = recipe.surfaceStyle;
      Settings.data.colorSchemes.seedIndex = recipe.seedIndex;
      Settings.data.colorSchemes.materialSpec = recipe.materialSpec;
    } finally {
      AppThemeService.recipeUpdateInProgress = false;
    }
    AppThemeService.generate();
  }

  Connections {
    target: AppThemeService
    function onRecipeUpdateInProgressChanged() {
      if (!AppThemeService.recipeUpdateInProgress)
        root.syncRecipe();
    }
  }

  Timer {
    id: generationDebounce
    interval: 250
    onTriggered: root.generateContextualPalette()
  }
  Connections {
    target: Settings.data.colorSchemes
    function onGenerationMethodChanged() {
      root.syncRecipe();
    }
    function onSurfaceStyleChanged() {
      root.syncRecipe();
    }
    function onSeedIndexChanged() {
      root.syncRecipe();
    }
    function onMaterialSpecChanged() {
      root.syncRecipe();
    }
  }
  FileView {
    path: Settings.configDir + "colors.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.diskColors = JSON.parse(text());
      } catch (error) {
        root.diskColors = null;
      }
    }
  }

  function updateColor(key, color) {
    if (!editingScheme || !editingScheme[editingVariant])
      return;
    const updated = clone(editingScheme);
    updated[editingVariant][key] = color.toString();
    editingScheme = updated;
    manualEdits = true;
    if (previewActive)
      applyPreview();
  }

  function openPicker(key) {
    if (!editingScheme)
      return;
    pickerTargetKey = key;
    colorPicker.selectedColor = editingScheme[editingVariant][key];
    colorPicker.open();
  }

  function copyHex(key, label) {
    if (!editingScheme)
      return;
    const hex = editingScheme[editingVariant][key].toUpperCase();
    Quickshell.execDetached(["wl-copy", hex]);
    ToastService.showNotice(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.copied", {
                                                                          "label": label,
                                                                          "color": hex
                                                                        }), "copy", 2500);
  }

  function startPreview() {
    if (previewActive || !editingScheme)
      return;
    originalColors = activeColors();
    previewActive = true;
    applyPreview();
  }

  function applyPreview() {
    if (!previewActive || !editingScheme)
      return;
    const variant = Settings.data.colorSchemes.darkMode ? editingScheme.dark : editingScheme.light;
    ColorSchemeService.writeColorsToDisk(variant);
  }

  function stopPreview() {
    if (!previewActive)
      return;
    previewActive = false;
    if (originalColors)
      ColorSchemeService.writeColorsToDisk(originalColors);
    originalColors = null;
  }

  function terminalColors(variant) {
    const surface = Qt.color(variant.mSurface);
    const isDark = (surface.r + surface.g + surface.b) / 3 < 0.5;
    const primary = Qt.color(variant.mPrimary);
    const saturation = primary.hsvSaturation > 0.3 ? primary.hsvSaturation : (isDark ? 0.70 : 0.65);
    const value = isDark ? 0.80 : 0.55;

    function colorAt(hue) {
      return Qt.hsva(hue / 360, saturation, value, 1).toString().toUpperCase();
    }
    function brighten(valueToBrighten) {
      const color = Qt.color(valueToBrighten);
      const hue = color.hsvHue < 0 ? 0 : color.hsvHue;
      return Qt.hsva(hue, Math.max(0, color.hsvSaturation - 0.1), Math.min(1, color.hsvValue + (isDark ? 0.15 : 0.20)), 1).toString().toUpperCase();
    }

    const green = colorAt(135);
    const yellow = colorAt(55);
    return {
      normal: {
        black: surface.toString().toUpperCase(),
        red: Qt.color(variant.mError).toString().toUpperCase(),
        green: green,
        yellow: yellow,
        blue: Qt.color(variant.mPrimary).toString().toUpperCase(),
        magenta: Qt.color(variant.mSecondary).toString().toUpperCase(),
        cyan: Qt.color(variant.mTertiary).toString().toUpperCase(),
        white: Qt.color(variant.mOnSurface).toString().toUpperCase()
      },
      bright: {
        black: Qt.color(variant.mSurfaceVariant).toString().toUpperCase(),
        red: brighten(variant.mError),
        green: brighten(green),
        yellow: brighten(yellow),
        blue: brighten(variant.mPrimary),
        magenta: brighten(variant.mSecondary),
        cyan: brighten(variant.mTertiary),
        white: isDark ? "#FFFFFF" : brighten(variant.mOnSurface)
      },
      foreground: Qt.color(variant.mOnSurface).toString().toUpperCase(),
      background: surface.toString().toUpperCase(),
      selectionFg: Qt.color(variant.mOnPrimary).toString().toUpperCase(),
      selectionBg: Qt.color(variant.mPrimary).toString().toUpperCase(),
      cursor: Qt.color(variant.mPrimary).toString().toUpperCase(),
      cursorText: Qt.color(variant.mOnPrimary).toString().toUpperCase()
    };
  }

  function saveScheme() {
    const name = schemeNameInput.text.trim();
    if (!name || !editingScheme || saving)
      return;
    const dark = clone(editingScheme.dark);
    const light = clone(editingScheme.light);
    dark.terminal = terminalColors(dark);
    light.terminal = terminalColors(light);
    const queued = ColorSchemeService.saveNamedScheme(name, {
                                                        dark: dark,
                                                        light: light
                                                      });
    saving = queued;
    if (!queued)
      ToastService.showError(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.save-error"));
  }

  FileView {
    id: schemeFileReader
    printErrors: false
    onLoaded: {
      try {
        const data = JSON.parse(text());
        root.editingScheme = data && data.dark && data.light ? {
                                                                 dark: root.clone(data.dark),
                                                                 light: root.clone(data.light)
                                                               } : root.fallbackScheme();
      } catch (error) {
        root.editingScheme = root.fallbackScheme();
        ToastService.showError(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.load-error"));
      }
    }
  }

  Connections {
    target: ColorSchemeService
    function onNamedSchemeSaved(success, name, path, error) {
      if (!root.saving)
        return;
      root.saving = false;
      if (!success) {
        ToastService.showError(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.save-error"));
        return;
      }
      root.previewActive = false;
      root.originalColors = null;
      Settings.data.colorSchemes.useWallpaperColors = false;
      Settings.data.colorSchemes.predefinedScheme = name;
      ColorSchemeService.applyScheme(path);
      ColorSchemeService.loadColorSchemes();
      ToastService.showNotice(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.saved", {
                                                                            "name": name
                                                                          }), "device-floppy", 3000);
    }
  }

  NColorPickerDialog {
    id: colorPicker
    screen: root.screen
    liveMode: root.previewActive
    onColorSelected: color => root.updateColor(root.pickerTargetKey, color)
  }

  RowLayout {
    anchors.fill: parent
    spacing: Style.marginL

    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 3
      color: Color.mSurfaceContainerLow
      radius: Style.radiusL

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          NIcon {
            icon: "color-swatch"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }

          NText {
            text: I18n.tr("wallpaper.palette.title")
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NButton {
            text: I18n.tr("wallpaper.palette.recalculate")
            icon: "refresh"
            fontSize: Style.fontSizeS
            enabled: !root.generating
            onClicked: root.regenerate()
          }
        }

        NText {
          Layout.fillWidth: true
          text: root.wallpaperPath.split("/").pop()
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          elide: Text.ElideMiddle
        }

        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: recipeContent.implicitHeight + Style.margin2M
          ColumnLayout {
            id: recipeContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS
            NText {
              text: I18n.tr("wallpaper.palette.generation")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }
            NComboBox {
              Layout.fillWidth: true
              label: I18n.tr("panels.color-scheme.wallpaper-method-label")
              model: TemplateProcessor.schemeTypes
              currentKey: root.draftModel
              onSelected: key => root.draftModel = key
            }
            NText {
              Layout.fillWidth: true
              text: I18n.tr("panels.color-scheme.method-description." + root.draftModel)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
            }
            RowLayout {
              Layout.fillWidth: true
              NText {
                text: I18n.tr("panels.color-scheme.material-spec-label")
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
              NTabBar {
                Layout.preferredWidth: 175 * Style.uiScaleRatio
                distributeEvenly: true
                enabled: root.materialRecipe
                currentIndex: root.draftMaterialSpec === "2025" ? 0 : 1
                NTabButton {
                  text: "2025"
                  tabIndex: 0
                  checked: root.draftMaterialSpec === "2025"
                  onClicked: root.draftMaterialSpec = "2025"
                }
                NTabButton {
                  text: "2021"
                  tabIndex: 1
                  checked: root.draftMaterialSpec === "2021"
                  onClicked: root.draftMaterialSpec = "2021"
                }
              }
            }
            RowLayout {
              Layout.fillWidth: true
              NText {
                text: I18n.tr("panels.color-scheme.surface-style-label")
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
              NTabBar {
                Layout.preferredWidth: 175 * Style.uiScaleRatio
                distributeEvenly: true
                enabled: root.materialRecipe
                currentIndex: root.draftSurfaceStyle === "tinted" ? 1 : 0
                NTabButton {
                  text: I18n.tr("panels.color-scheme.surface-style-classic")
                  tabIndex: 0
                  checked: root.draftSurfaceStyle !== "tinted"
                  onClicked: root.draftSurfaceStyle = "classic"
                }
                NTabButton {
                  text: "Tinted"
                  tabIndex: 1
                  checked: root.draftSurfaceStyle === "tinted"
                  onClicked: root.draftSurfaceStyle = "tinted"
                }
              }
            }
            NText {
              text: I18n.tr("wallpaper.palette.seed")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
            GridLayout {
              Layout.fillWidth: true
              columns: width >= 420 * Style.uiScaleRatio ? 4 : 2
              columnSpacing: Style.marginS
              rowSpacing: Style.marginS
              visible: root.candidates.length > 0
              Repeater {
                model: root.candidates
                NBox {
                  id: seedChip
                  required property var modelData
                  readonly property bool selected: root.draftSeedIndex === modelData.index
                  Layout.fillWidth: true
                  Layout.preferredHeight: 34 * Style.uiScaleRatio
                  color: selected ? Color.mPrimaryContainer : (seedMouse.containsMouse ? Color.mSurfaceContainerHighest : Color.mSurfaceContainer)
                  border.color: selected ? Color.mPrimary : "transparent"
                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    spacing: Style.marginS
                    Rectangle {
                      Layout.preferredWidth: 18 * Style.uiScaleRatio
                      Layout.preferredHeight: 18 * Style.uiScaleRatio
                      radius: height / 2
                      color: seedChip.modelData.hex
                    }
                    NText {
                      Layout.fillWidth: true
                      text: seedChip.modelData.hex
                      pointSize: Style.fontSizeXS
                      color: seedChip.selected ? Color.mOnPrimaryContainer : Color.mOnSurface
                      elide: Text.ElideRight
                    }
                    NIcon {
                      icon: "check"
                      visible: seedChip.selected
                      pointSize: Style.fontSizeXS
                      color: Color.mOnPrimaryContainer
                    }
                  }
                  MouseArea {
                    id: seedMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.draftSeedIndex = seedChip.modelData.index
                  }
                }
              }
            }
            NText {
              Layout.fillWidth: true
              text: root.generationError || (root.generating ? I18n.tr("wallpaper.palette.generating") : (!root.materialRecipe ? I18n.tr("wallpaper.palette.legacy-extraction") : (root.draftModel === "smart" ? "Smart → " + root.effectiveModel : I18n.tr("wallpaper.palette.recipe-note"))))
              pointSize: Style.fontSizeXS
              wrapMode: Text.WordWrap
              color: root.generationError ? Color.mError : Color.mOnSurfaceVariant
            }
            NText {
              Layout.fillWidth: true
              visible: root.materialRecipe && !root.generating && root.draftMaterialSpec === "2025" && root.effectiveMaterialSpec === "2021"
              text: I18n.tr("panels.color-scheme.material-spec-fallback")
              pointSize: Style.fontSizeXS
              wrapMode: Text.WordWrap
              color: Color.mOnSurfaceVariant
            }
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        RowLayout {
          Layout.fillWidth: true

          NText {
            text: I18n.tr("wallpaper.palette.edit-roles")
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
          }

          NToggle {
            Layout.preferredWidth: Math.round(170 * Style.uiScaleRatio)
            label: root.editingVariant === "dark" ? I18n.tr("wallpaper.palette.dark") : I18n.tr("wallpaper.palette.light")
            checked: root.editingVariant === "light"
            onToggled: checked => root.editingVariant = checked ? "light" : "dark"
          }
        }

        NScrollView {
          id: roleScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          gradientColor: Color.mSurfaceContainerLow

          GridLayout {
            width: roleScroll.availableWidth
            columns: 2
            columnSpacing: Style.marginM
            rowSpacing: Style.marginS

            Repeater {
              model: root.colorRoles

              NBox {
                id: roleCard
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(48 * Style.uiScaleRatio)
                color: Color.mSurfaceContainer
                radius: Style.radiusS

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: Style.marginS

                  Rectangle {
                    Layout.preferredWidth: Math.round(30 * Style.uiScaleRatio)
                    Layout.preferredHeight: Math.round(30 * Style.uiScaleRatio)
                    radius: Style.radiusS
                    color: root.editingScheme ? root.editingScheme[root.editingVariant][roleCard.modelData.key] : Color.mSurface
                    border.color: Color.mOutline
                    border.width: Style.borderS

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.openPicker(roleCard.modelData.key)
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    NText {
                      text: I18n.tr("wallpaper.palette.roles." + roleCard.modelData.labelKey)
                      color: Color.mOnSurface
                      pointSize: Style.fontSizeS
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    NText {
                      text: root.editingScheme ? root.editingScheme[root.editingVariant][roleCard.modelData.key].toUpperCase() : ""
                      color: Color.mOnSurfaceVariant
                      family: Settings.data.ui.fontFixed
                      pointSize: Style.fontSizeXS
                    }
                  }

                  NIconButton {
                    icon: "copy"
                    tooltipText: I18n.tr("wallpaper.palette.copy-color")
                    baseSize: Style.baseWidgetSize * 0.7
                    colorBorder: "transparent"
                    colorBorderHover: "transparent"
                    onClicked: root.copyHex(roleCard.modelData.key, I18n.tr("wallpaper.palette.roles." + roleCard.modelData.labelKey))
                  }
                }
              }
            }
          }
        }
      }
    }

    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 2
      color: Color.mSurfaceContainerHigh
      radius: Style.radiusL

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
          text: I18n.tr("wallpaper.palette.save-title")
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }

        NText {
          text: I18n.tr("wallpaper.palette.description")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        NDivider {
          Layout.fillWidth: true
        }

        NTextInput {
          id: schemeNameInput
          Layout.fillWidth: true
          label: I18n.tr("wallpaper.palette.scheme-name")
          placeholderText: I18n.tr("wallpaper.palette.scheme-name-placeholder")
        }

        NButton {
          Layout.fillWidth: true
          text: root.previewActive ? I18n.tr("wallpaper.palette.cancel-preview") : I18n.tr("wallpaper.palette.preview")
          icon: root.previewActive ? "restore" : "eye"
          outlined: !root.previewActive
          enabled: !!root.editingScheme && !root.saving
          onClicked: root.previewActive ? root.stopPreview() : root.startPreview()
        }

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("wallpaper.palette.reset")
          icon: "refresh"
          outlined: true
          enabled: !root.saving
          onClicked: root.resetEditor()
        }

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("wallpaper.palette.apply-recipe")
          icon: "palette"
          outlined: true
          enabled: root.activeColorSource && !!root.editingScheme && !root.generating && !root.saving
          onClicked: root.applyRecipe()
        }
        NButton {
          Layout.fillWidth: true
          text: root.saving ? I18n.tr("wallpaper.palette.saving") : I18n.tr("wallpaper.palette.save-apply")
          icon: "device-floppy"
          enabled: schemeNameInput.text.trim().length > 0 && !!root.editingScheme && !root.saving
          onClicked: root.saveScheme()
        }

        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: previewStatus.implicitHeight + Style.margin2M
          color: root.previewActive ? Color.mSecondaryContainer : Color.mSurfaceContainerHighest
          radius: Style.radiusM

          RowLayout {
            id: previewStatus
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NIcon {
              icon: root.previewActive ? "eye" : "palette"
              color: root.previewActive ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
            }

            NText {
              text: root.previewActive ? I18n.tr("wallpaper.palette.preview-active") : I18n.tr("wallpaper.palette.preview-inactive")
              color: root.previewActive ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }

        Item {
          Layout.fillHeight: true
        }

        NText {
          text: I18n.tr("wallpaper.palette.terminal-note")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }
  }
}
