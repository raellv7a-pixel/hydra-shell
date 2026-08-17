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

  readonly property var colorRoles: [
    { key: "mPrimary", labelKey: "primary" },
    { key: "mOnPrimary", labelKey: "on-primary" },
    { key: "mSecondary", labelKey: "secondary" },
    { key: "mOnSecondary", labelKey: "on-secondary" },
    { key: "mTertiary", labelKey: "tertiary" },
    { key: "mOnTertiary", labelKey: "on-tertiary" },
    { key: "mError", labelKey: "error" },
    { key: "mOnError", labelKey: "on-error" },
    { key: "mSurface", labelKey: "surface" },
    { key: "mOnSurface", labelKey: "on-surface" },
    { key: "mSurfaceVariant", labelKey: "surface-variant" },
    { key: "mOnSurfaceVariant", labelKey: "on-surface-variant" },
    { key: "mOutline", labelKey: "outline" },
    { key: "mShadow", labelKey: "shadow" },
    { key: "mHover", labelKey: "hover" },
    { key: "mOnHover", labelKey: "on-hover" }
  ]

  Component.onCompleted: seedEditor()
  Component.onDestruction: stopPreview()
  onVisibleChanged: {
    if (!visible)
      stopPreview();
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function activeColors() {
    return {
      mPrimary: Color.mPrimary.toString(),
      mOnPrimary: Color.mOnPrimary.toString(),
      mSecondary: Color.mSecondary.toString(),
      mOnSecondary: Color.mOnSecondary.toString(),
      mTertiary: Color.mTertiary.toString(),
      mOnTertiary: Color.mOnTertiary.toString(),
      mError: Color.mError.toString(),
      mOnError: Color.mOnError.toString(),
      mSurface: Color.mSurface.toString(),
      mOnSurface: Color.mOnSurface.toString(),
      mSurfaceVariant: Color.mSurfaceVariant.toString(),
      mOnSurfaceVariant: Color.mOnSurfaceVariant.toString(),
      mOutline: Color.mOutline.toString(),
      mShadow: Color.mShadow.toString(),
      mHover: Color.mHover.toString(),
      mOnHover: Color.mOnHover.toString()
    };
  }

  function fallbackScheme() {
    const colors = activeColors();
    return { dark: colors, light: clone(colors) };
  }

  function seedEditor() {
    stopPreview();
    editingVariant = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    schemeNameInput.text = "";
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

  function updateColor(key, color) {
    if (!editingScheme || !editingScheme[editingVariant])
      return;
    const updated = clone(editingScheme);
    updated[editingVariant][key] = color.toString();
    editingScheme = updated;
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
    ToastService.showNotice(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.copied", { "label": label, "color": hex }), "copy", 2500);
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
        black: surface.toString().toUpperCase(), red: Qt.color(variant.mError).toString().toUpperCase(),
        green: green, yellow: yellow, blue: Qt.color(variant.mPrimary).toString().toUpperCase(),
        magenta: Qt.color(variant.mSecondary).toString().toUpperCase(), cyan: Qt.color(variant.mTertiary).toString().toUpperCase(),
        white: Qt.color(variant.mOnSurface).toString().toUpperCase()
      },
      bright: {
        black: Qt.color(variant.mSurfaceVariant).toString().toUpperCase(), red: brighten(variant.mError),
        green: brighten(green), yellow: brighten(yellow), blue: brighten(variant.mPrimary),
        magenta: brighten(variant.mSecondary), cyan: brighten(variant.mTertiary),
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
    const queued = ColorSchemeService.saveNamedScheme(name, { dark: dark, light: light });
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
        root.editingScheme = data && data.dark && data.light ? { dark: root.clone(data.dark), light: root.clone(data.light) } : root.fallbackScheme();
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
      ToastService.showNotice(I18n.tr("wallpaper.palette.title"), I18n.tr("wallpaper.palette.saved", { "name": name }), "device-floppy", 3000);
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
            onClicked: {
              root.stopPreview();
              AppThemeService.generate();
              Qt.callLater(root.seedEditor);
            }
          }
        }

        NDivider { Layout.fillWidth: true }

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

        NDivider { Layout.fillWidth: true }

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
          onClicked: root.seedEditor()
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

        Item { Layout.fillHeight: true }

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
