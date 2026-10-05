import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.Theming
import qs.Widgets

Item {
  id: root

  property string selectedScheme: "Hydra Glacier"
  property bool darkMode: true
  property bool useWallpaperColors: false
  property bool busy: false
  property bool wallpaperAvailable: true

  signal schemeSelected(string name)
  signal darkModeSelected(bool dark)
  signal wallpaperColorsSelected(bool enabled)

  readonly property var officialSchemes: [
    { name: "Hydra Glacier", basename: "Hydra-Glacier" },
    { name: "Hydra Sage", basename: "Hydra-Sage" },
    { name: "Hydra Cobalt", basename: "Hydra-Cobalt" },
    { name: "Hydra Ember", basename: "Hydra-Ember" },
    { name: "Hydra Graphite", basename: "Hydra-Graphite" }
  ]

  property var schemeColorsCache: ({})
  property int cacheVersion: 0

  function extractSchemeName(path) {
    return ColorSchemeService.getBasename(path);
  }

  function getSchemeColor(schemeName, key) {
    // Explicit binding to cacheVersion guarantees reactivity
    const _ = cacheVersion;
    try {
      const mode = root.darkMode ? "dark" : "light";
      const data = schemeColorsCache[schemeName];
      if (data && data[mode] && data[mode][key]) {
        return data[mode][key];
      }
    } catch (e) {}

    // Fall back strictly to live Color design system tokens
    if (key === "mPrimary") return Color.mPrimary;
    if (key === "mSecondary") return Color.mSecondary;
    if (key === "mTertiary") return Color.mTertiary;
    if (key === "mPrimaryContainer") return Color.mPrimaryContainer;
    if (key === "mSurface") return Color.mSurface;
    if (key === "mSurfaceContainer") return Color.mSurfaceContainer;
    if (key === "mSurfaceContainerHigh") return Color.mSurfaceContainerHigh;
    if (key === "mSurfaceContainerLowest") return Color.mSurfaceContainerLowest;
    if (key === "mOnSurface") return Color.mOnSurface;
    if (key === "mOnSurfaceVariant") return Color.mOnSurfaceVariant;
    return Color.mSurfaceVariant;
  }

  Repeater {
    model: officialSchemes
    delegate: Item {
      required property var modelData
      FileView {
        path: ColorSchemeService.resolveSchemePath(modelData.basename)
        onLoaded: {
          try {
            const parsed = JSON.parse(text());
            const nextCache = Object.assign({}, root.schemeColorsCache);
            nextCache[modelData.name] = parsed;
            nextCache[modelData.basename] = parsed;
            root.schemeColorsCache = nextCache;
            root.cacheVersion++;
          } catch (e) {}
        }
      }
    }
  }

  NScrollView {
    anchors.fill: parent
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AlwaysOff

    ColumnLayout {
      width: parent.width
      spacing: Style.marginL

      // Header
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NText {
          text: I18n.tr("setup.hydra.theme.title")
          pointSize: Style.fontSizeXXL
          font.weight: Style.fontWeightBold
          color: Color.mPrimary
          Layout.fillWidth: true
        }

        NText {
          text: I18n.tr("setup.hydra.theme.subtitle")
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }

      // Toggles (semantic Material surface, no outline border)
      Rectangle {
        Layout.fillWidth: true
        radius: Style.radiusL
        color: Color.mSurfaceContainerLow
        implicitHeight: toggleColumn.implicitHeight + Style.marginL * 2

        ColumnLayout {
          id: toggleColumn
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          NToggle {
            Layout.fillWidth: true
            label: I18n.tr("setup.hydra.theme.dark-mode")
            description: I18n.tr("setup.hydra.theme.dark-mode-desc")
            icon: "moon"
            checked: root.darkMode
            enabled: !root.busy
            onToggled: checked => root.darkModeSelected(checked)
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Color.mOutline, 0.15)
          }

          NToggle {
            Layout.fillWidth: true
            label: I18n.tr("setup.hydra.theme.wallpaper-colors")
            description: root.wallpaperAvailable ?
                         I18n.tr("setup.hydra.theme.wallpaper-colors-desc") :
                         I18n.tr("setup.hydra.theme.wallpaper-colors-disabled")
            icon: "photo"
            checked: root.useWallpaperColors
            enabled: !root.busy && root.wallpaperAvailable
            onToggled: checked => root.wallpaperColorsSelected(checked)
          }
        }
      }

      // Section label for schemes
      NText {
        text: I18n.tr("setup.hydra.theme.presets-title")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
      }

      // Official 5 color schemes responsive grid (1 col narrow, 2 col regular)
      GridLayout {
        Layout.fillWidth: true
        columns: parent.width > 560 ? 2 : 1
        rowSpacing: Style.marginM
        columnSpacing: Style.marginM

        Repeater {
          model: root.officialSchemes

          delegate: Rectangle {
            id: card
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: 96 * Style.uiScaleRatio
            radius: Style.radiusM
            activeFocusOnTab: true

            readonly property bool isSelected: !root.useWallpaperColors && (root.selectedScheme === modelData.name || root.selectedScheme === modelData.basename)

            color: isSelected ? Color.mPrimaryContainer : Color.mSurfaceContainer
            // Semantic border only for focus or selection; no permanent border
            border.width: card.activeFocus ? Style.borderL : (isSelected ? Style.borderM : 0)
            border.color: card.activeFocus ? Color.mPrimary : (isSelected ? Color.mPrimary : "transparent")

            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.name
            Accessible.checked: isSelected

            Keys.onSpacePressed: event => {
              if (!root.busy) root.schemeSelected(modelData.name);
              event.accepted = true;
            }
            Keys.onReturnPressed: event => {
              if (!root.busy) root.schemeSelected(modelData.name);
              event.accepted = true;
            }
            Keys.onEnterPressed: event => {
              if (!root.busy) root.schemeSelected(modelData.name);
              event.accepted = true;
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.busy
              onClicked: {
                card.forceActiveFocus();
                root.schemeSelected(modelData.name);
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginM

              // Framed mini desktop: dashboard above, launcher attached below.
              Rectangle {
                Layout.preferredWidth: 110 * Style.uiScaleRatio
                Layout.preferredHeight: 64 * Style.uiScaleRatio
                radius: Style.radiusS
                color: root.getSchemeColor(modelData.name, "mSurfaceContainerHigh")
                Accessible.ignored: true

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: Style.margin2XS
                  anchors.topMargin: Style.marginS
                  radius: Style.radiusXS
                  color: root.getSchemeColor(modelData.name, "mSurfaceContainerLowest")

                  Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6
                    height: parent.height * 0.38
                    radius: Style.radiusXS
                    color: root.getSchemeColor(modelData.name, "mSurfaceContainer")

                    Row {
                      anchors.centerIn: parent
                      spacing: Style.margin2XS
                      Repeater {
                        model: ["mPrimary", "mSecondary", "mTertiary"]
                        Rectangle {
                          required property string modelData
                          width: 12 * Style.uiScaleRatio
                          height: 6 * Style.uiScaleRatio
                          radius: Style.radiusXS
                          color: root.getSchemeColor(card.modelData.name, modelData)
                        }
                      }
                    }
                  }

                  Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.72
                    height: parent.height * 0.42
                    radius: Style.radiusXS
                    color: root.getSchemeColor(modelData.name, "mSurface")

                    Rectangle {
                      anchors.centerIn: parent
                      width: parent.width * 0.8
                      height: 6 * Style.uiScaleRatio
                      radius: Style.radiusXS
                      color: root.getSchemeColor(modelData.name, "mPrimaryContainer")
                    }
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.margin2XS

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS
                  NText {
                    text: modelData.name
                    font.weight: card.isSelected ? Style.fontWeightBold : Style.fontWeightMedium
                    color: card.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurface
                    pointSize: Style.fontSizeM
                    Layout.fillWidth: true
                  }
                  NText {
                    visible: card.index === 0
                    text: I18n.tr("common.default")
                    pointSize: Style.fontSizeXS
                    color: card.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
                  }
                }

                NText {
                  text: I18n.tr("setup.hydra.theme." + modelData.basename.toLowerCase().replace("hydra-", "") + "-desc")
                  color: card.isSelected ? Qt.alpha(Color.mOnPrimaryContainer, 0.8) : Color.mOnSurfaceVariant
                  pointSize: Style.fontSizeS
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
              }

              // Selected check indicator
              NIcon {
                visible: card.isSelected
                icon: "check"
                pointSize: Style.fontSizeM
                color: Color.mPrimary
              }
            }
          }
        }
      }
    }
  }
}
