import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Noctalia
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // When true, only shows step 0 with modified text for returning users (telemetry notification)
  property bool telemetryOnlyMode: false

  signal telemetryWizardCompleted

  preferredWidth: Math.round(preferredWidthRatio * 2560 * Style.uiScaleRatio)
  preferredHeight: Math.round(preferredHeightRatio * 1440 * Style.uiScaleRatio)
  preferredWidthRatio: 0.4
  preferredHeightRatio: root.telemetryOnlyMode ? 0.45 : 0.6

  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true

  closeWithEscape: false

  panelContent: Item {
    id: panelContent

    // Wizard state (lazy-loaded with panelContent)
    property int currentStep: 0
    readonly property int totalSteps: root.telemetryOnlyMode ? 1 : 6
    property bool isCompleting: false

    // Setup wizard data
    property string selectedWallpaperDirectory: Settings.defaultWallpapersDirectory
    property string selectedWallpaper: ""
    property real selectedScaleRatio: 1.0
    property string selectedBarPosition: "top"

    Component.onCompleted: {
      selectedScaleRatio = Settings.data.general.scaleRatio;
      selectedBarPosition = Settings.data.bar.position;
      selectedWallpaperDirectory = Settings.data.wallpaper.directory || Settings.defaultWallpapersDirectory;
    }

    Connections {
      target: Settings
      function onSettingsSaved() {
        if (panelContent.isCompleting) {
          Logger.i("SetupWizard", "Settings saved, closing panel");
          panelContent.isCompleting = false;
          root.close();
        }
      }
    }

    Timer {
      id: closeTimer
      interval: 2000
      onTriggered: {
        if (panelContent.isCompleting) {
          Logger.w("SetupWizard", "Settings save timeout, closing panel anyway");
          panelContent.isCompleting = false;
          root.close();
        }
      }
    }

    function completeSetup() {
      if (isCompleting) {
        Logger.w("SetupWizard", "completeSetup() called while already completing, ignoring");
        return;
      }

      try {
        Logger.i("SetupWizard", root.telemetryOnlyMode ? "Completing telemetry wizard" : "Completing setup with selected options");
        isCompleting = true;

        // In telemetry-only mode, we only need to save the telemetry setting
        if (!root.telemetryOnlyMode) {
          if (typeof WallpaperService !== "undefined" && WallpaperService.refreshWallpapersList) {
            if (selectedWallpaperDirectory !== Settings.data.wallpaper.directory) {
              Settings.data.wallpaper.directory = selectedWallpaperDirectory;
              WallpaperService.refreshWallpapersList();
            }

            if (selectedWallpaper !== "") {
              WallpaperService.changeWallpaper(selectedWallpaper, undefined);
            }
          }

          Settings.data.general.scaleRatio = selectedScaleRatio;
          Settings.data.bar.position = selectedBarPosition;
        }

        // Mark the current version as seen to prevent telemetry wizard on next startup
        // (only for full setup wizard - telemetry wizard lets changelog mark it seen)
        if (!root.telemetryOnlyMode) {
          UpdateService.markChangelogSeen(UpdateService.currentVersion);
        }

        // Initialize telemetry now that user has made their choice
        TelemetryService.init();

        // Save settings immediately and wait for settingsSaved signal before closing
        Settings.saveImmediate();
        Logger.i("SetupWizard", "Setup completed successfully, waiting for settings save confirmation");

        // Emit signal for telemetry wizard completion (shell.qml will show changelog)
        if (root.telemetryOnlyMode) {
          root.telemetryWizardCompleted();
        }

        // Fallback: if settingsSaved signal doesn't fire within 2 seconds, close anyway
        closeTimer.start();
      } catch (error) {
        Logger.e("SetupWizard", "Error completing setup:", error);
        isCompleting = false;
      }
    }

    function applyWallpaperSettings() {
      if (typeof WallpaperService !== "undefined" && WallpaperService.refreshWallpapersList) {
        if (selectedWallpaperDirectory !== Settings.data.wallpaper.directory) {
          Settings.data.wallpaper.directory = selectedWallpaperDirectory;
          WallpaperService.refreshWallpapersList();
        }

        if (selectedWallpaper !== "") {
          WallpaperService.changeWallpaper(selectedWallpaper, undefined);
        }
      }
    }

    function applyUISettings() {
      Settings.data.general.scaleRatio = selectedScaleRatio;
      Settings.data.bar.position = selectedBarPosition;
    }

    ColumnLayout {
      id: wizardContent
      anchors.fill: parent
      anchors.margins: Style.radiusPanel // must be >= the panel's own blob corner radius (28px), not paddingCard (16px), or content stops short and the wallpaper shows through the rounded-off corner
      spacing: Style.spaceS

      // Step content - takes most of the space
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Math.round(300 * Style.uiScaleRatio)

        StackLayout {
          id: stepStack
          anchors.fill: parent
          currentIndex: currentStep

          // Step 0: Welcome - Beautiful centered design
          Item {
            ColumnLayout {
              anchors.centerIn: parent
              width: Math.min(parent.width - Style.paddingCard * 2, Math.round(760 * Style.uiScaleRatio))
              spacing: Style.spaceL

              // Logo with subtle glow effect
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(96 * Style.uiScaleRatio)
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                  id: brandMark
                  anchors.centerIn: parent
                  width: Math.round(96 * Style.uiScaleRatio)
                  height: width
                  radius: Style.radiusCard
                  color: Color.mPrimaryContainer
                  border.color: Qt.alpha(Color.mPrimary, 0.38)
                  border.width: Style.borderS

                  NIcon {
                    anchors.centerIn: parent
                    icon: "sparkles"
                    pointSize: Style.fontSizeDisplaySmall
                    color: Color.mOnPrimaryContainer
                  }

                  SequentialAnimation on scale {
                    running: Style.motionEnabled && brandMark.visible
                    loops: Animation.Infinite

                    NAnim {
                      from: 1.0
                      to: 1.04
                      duration: Style.motionDurationSlowSpatial * 2
                      motionType: NAnim.ExpressiveSlowSpatial
                    }

                    NAnim {
                      from: 1.04
                      to: 1.0
                      duration: Style.motionDurationSlowSpatial * 2
                      motionType: NAnim.ExpressiveSlowSpatial
                    }
                  }
                }
              }

              // Welcome text with gradient feel
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.spaceS

                NText {
                  text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-title") : I18n.tr("setup.welcome-title")
                  pointSize: Style.fontSizeHeadlineMedium
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                }

                NText {
                  text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-subtitle") : I18n.tr("setup.welcome-subtitle")
                  pointSize: Style.fontSizeBodyLarge
                  color: Color.mOnSurfaceVariant
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                // Friendly subtext
                Rectangle {
                  Layout.fillWidth: true
                  Layout.topMargin: Style.spaceL
                  Layout.preferredHeight: childrenRect.height + Style.paddingCard * 2
                  color: Color.mSurfaceContainerHigh
                  radius: Style.radiusCard

                  NText {
                    anchors.centerIn: parent
                    width: parent.width - Style.paddingCard * 2
                    text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-note") : I18n.tr("setup.welcome-note")
                    pointSize: Style.fontSizeBodyMedium
                    color: Color.mOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                  }
                }

                // Telemetry toggle
                NToggle {
                  Layout.fillWidth: true
                  Layout.topMargin: Style.spaceS
                  label: I18n.tr("panels.about.telemetry-enabled")
                  description: I18n.tr("panels.about.telemetry-desc")
                  checked: Settings.data.general.telemetryEnabled
                  onToggled: checked => Settings.data.general.telemetryEnabled = checked
                }
              }
            }
          }

          // Step 1: Hyprland ownership (PLANO_INTEGRACAO_HYPRMOD.md §4.2)
          SetupHyprlandStep {
            id: stepHyprland
          }

          // Step 1: Wallpaper Setup
          SetupWallpaperStep {
            id: step1
            selectedDirectory: panelContent.selectedWallpaperDirectory
            selectedWallpaper: panelContent.selectedWallpaper
            onDirectoryChanged: function (directory) {
              panelContent.selectedWallpaperDirectory = directory;
              panelContent.applyWallpaperSettings();
            }
            onWallpaperChanged: function (wallpaper) {
              panelContent.selectedWallpaper = wallpaper;
              panelContent.applyWallpaperSettings();
            }
          }

          // Step 2: Appearance - Dark mode and color source
          SetupAppearanceStep {
            id: step3
          }

          // Step 3: UI Configuration
          SetupCustomizeStep {
            id: step2
            selectedScaleRatio: panelContent.selectedScaleRatio
            selectedBarPosition: panelContent.selectedBarPosition
            onScaleRatioChanged: function (ratio) {
              panelContent.selectedScaleRatio = ratio;
              panelContent.applyUISettings();
            }
            onBarPositionChanged: function (position) {
              panelContent.selectedBarPosition = position;
              panelContent.applyUISettings();
            }
          }

          // Step 4: Dock Setup
          SetupDockStep {
            id: stepDock
          }
        }
      }

      // Elegant divider
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Color.mOutline
        opacity: 0.2
        visible: !root.telemetryOnlyMode
      }

      // Modern progress indicator with labels
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        visible: !root.telemetryOnlyMode

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.spaceS

          Repeater {
            model: [
              {
                "icon": "sparkles",
                "label": I18n.tr("setup.welcome")
              },
              {
                "icon": "keyboard",
                "label": "Hyprland"
              },
              {
                "icon": "image",
                "label": I18n.tr("common.wallpaper")
              },
              {
                "icon": "palette",
                "label": I18n.tr("common.appearance")
              },
              {
                "icon": "settings",
                "label": I18n.tr("common.customize")
              },
              {
                "icon": "device-desktop",
                "label": I18n.tr("panels.dock.title")
              }
            ]
            delegate: RowLayout {
              spacing: Style.spaceS

              Rectangle {
                readonly property bool completed: index < currentStep
                readonly property bool active: index === currentStep

                width: Math.round(28 * Style.uiScaleRatio)
                height: width
                radius: Style.radiusCapsule
                color: active ? Color.mPrimaryContainer : (completed ? Color.mPrimary : Color.mSurfaceContainerHigh)
                scale: active ? 1.08 : 1.0

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeBodySmall
                  color: parent.active ? Color.mOnPrimaryContainer : (parent.completed ? Color.mOnPrimary : Color.mOnSurfaceVariant)
                  anchors.centerIn: parent

                  Behavior on color {
                    NColorAnimation {
                      motionType: NColorAnimation.Standard
                    }
                  }
                }

                Behavior on color {
                  NColorAnimation {
                    motionType: NColorAnimation.Standard
                  }
                }

                Behavior on scale {
                  NAnim {
                    motionType: NAnim.ExpressiveFastSpatial
                  }
                }
              }

              NText {
                text: modelData.label
                pointSize: Style.fontSizeLabelLarge
                color: index <= currentStep ? Color.mPrimary : Color.mOnSurfaceVariant
                font.weight: index === currentStep ? Style.fontWeightBold : Style.fontWeightMedium

                Behavior on color {
                  NColorAnimation {
                    motionType: NColorAnimation.Standard
                  }
                }
              }

              Rectangle {
                width: Math.round(24 * Style.uiScaleRatio)
                height: 2
                radius: Style.radiusCapsule
                color: index < currentStep ? Color.mPrimary : Color.mSurfaceContainerHigh
                visible: index < totalSteps - 1

                Behavior on color {
                  NColorAnimation {
                    motionType: NColorAnimation.Standard
                  }
                }
              }
            }
          }
        }
      }

      // Smooth navigation buttons
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.topMargin: Style.spaceS

        RowLayout {
          anchors.fill: parent
          spacing: Style.spaceS

          NButton {
            text: I18n.tr("setup.skip-setup")
            outlined: true
            visible: !root.telemetryOnlyMode
            Layout.preferredHeight: 44
            fontSize: Style.fontSizeBodySmall
            onClicked: {
              panelContent.completeSetup();
            }
          }

          Item {
            Layout.fillWidth: true
          }

          NButton {
            text: "← " + I18n.tr("common.back")
            outlined: true
            visible: currentStep > 0 && !root.telemetryOnlyMode
            Layout.preferredHeight: 44
            fontSize: Style.fontSizeBodySmall
            onClicked: {
              if (currentStep > 0) {
                currentStep--;
              }
            }
          }

          NButton {
            text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-done") : (currentStep === totalSteps - 1 ? I18n.tr("setup.all-done") : I18n.tr("common.continue") + " →")
            Layout.preferredHeight: 44
            fontSize: Style.fontSizeBodySmall
            onClicked: {
              if (currentStep < totalSteps - 1) {
                currentStep++;
              } else {
                panelContent.completeSetup();
              }
            }
          }
        }
      }
    }
  }
}
