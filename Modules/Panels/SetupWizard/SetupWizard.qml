import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Hydra
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root
  property bool telemetryOnlyMode: false
  property bool mandatorySession: false
  property bool sessionAccepted: false
  signal telemetryWizardCompleted

  // First-run is a focused task, not an ordinary frame-attached shell panel.
  modalOverlay: true
  exclusiveKeyboard: true
  closeWithEscape: false
  allowButtonPosition: false
  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true
  panelBackgroundColor: Color.mSurfaceContainer
  preferredWidth: Math.min(1040 * Math.min(Style.uiScaleRatio, 1.25), (screen?.width || 1040) - Style.margin2XL - frameThickness * 2)
  preferredHeight: Math.min((telemetryOnlyMode ? 520 : 740) * Math.min(Style.uiScaleRatio, 1.25), (screen?.height || 800) - barHeight - Style.margin2XL - frameThickness * 2)

  SetupThemeSession { id: themeSession }

  function onEscapePressed() {
    if (!mandatorySession && contentItem)
      contentItem.cancelSession();
  }
  onIsClosingChanged: {
    if (isClosing && !sessionAccepted && !telemetryOnlyMode)
      themeSession.cancel();
  }
  onClosed: {
    if (sessionAccepted && telemetryOnlyMode)
      telemetryWizardCompleted();
  }

  panelContent: FocusScope {
    id: flow
    readonly property real contentPreferredWidth: root.preferredWidth
    readonly property real contentPreferredHeight: root.preferredHeight
    readonly property bool allowAttach: false
    property int currentStep: 0
    property string selectedScheme: Settings.data.colorSchemes.predefinedScheme
    property bool selectedDark: Settings.data.colorSchemes.darkMode
    property bool selectedWallpaperColors: Settings.data.colorSchemes.useWallpaperColors
    property string selectedMaterialSpec: Settings.data.colorSchemes.materialSpec
    property bool selectedTelemetry: Settings.data.general.telemetryEnabled
    property bool selectedRecommended: false
    property string finishState: "idle"
    property string errorMessage: ""
    property bool initialTelemetry: false
    property string initialIntegration: ""
    readonly property bool busy: finishState !== "idle" || themeSession.busy
    readonly property var displayStep: displayLoader.item
    readonly property var controlsStep: controlsLoader.item
    readonly property bool displayBlocked: !root.telemetryOnlyMode && (!displayStep || displayStep.blocked)
    readonly property var stepKeys: ["displays", "style", "discover", "controls", "ready"]
    readonly property var stepIcons: ["device-desktop", "palette", "sparkles", "keyboard", "circle-check"]

    Component.onCompleted: {
      // Capture values, rather than retaining bindings to finalization writes.
      initialTelemetry = Settings.data.general.telemetryEnabled;
      initialIntegration = Settings.data.general.umbrielKeybindIntegration;
      root.sessionAccepted = false;
      root.mandatorySession = !root.telemetryOnlyMode && Settings.shouldOpenSetupWizard;
      selectedRecommended = root.mandatorySession || Settings.data.general.umbrielKeybindIntegration !== "preserve";
      if (root.mandatorySession) {
        selectedMaterialSpec = "2025";
        selectedTelemetry = false;
      }
      if (!root.telemetryOnlyMode)
        themeSession.begin();
      forceActiveFocus();
    }

    function previewStyle() {
      errorMessage = "";
      if (selectedWallpaperColors)
        themeSession.previewWallpaper(selectedDark);
      else
        themeSession.previewScheme(selectedScheme, selectedDark);
    }
    function changeStep(index) {
      currentStep = index;
      pageMotion.restart();
    }
    function cancelSession() {
      if (root.mandatorySession || busy)
        return;
      if (!root.telemetryOnlyMode && !displayStep.discardDraft()) {
        errorMessage = I18n.tr("setup.hydra.resolve-displays");
        return;
      }
      if (themeSession.cancel())
        root.close();
    }
    function useDefaults() {
      if (busy || !displayStep.discardDraft()) {
        errorMessage = I18n.tr("setup.hydra.resolve-displays");
        return;
      }
      selectedScheme = "Hydra Glacier";
      selectedDark = true;
      selectedWallpaperColors = false;
      selectedMaterialSpec = "2025";
      selectedRecommended = true;
      selectedTelemetry = false;
      finish();
    }
    function finish() {
      if (busy || displayBlocked)
        return;
      errorMessage = "";
      if (root.telemetryOnlyMode) {
        persistCompletion();
        return;
      }
      finishState = "controls";
      controlsStep.commit();
    }
    function persistCompletion() {
      finishState = "saving";
      Settings.data.general.telemetryEnabled = selectedTelemetry;
      if (!root.telemetryOnlyMode) {
        Settings.data.general.umbrielKeybindIntegration = selectedRecommended && !controlsStep.externallyOwned ? "recommended" : "preserve";
        Settings.data.onboardingVersion = Math.max(Settings.data.onboardingVersion, Settings.currentOnboardingVersion);
      }
      Settings.saveImmediate();
    }
    function fail(message) {
      finishState = "idle";
      errorMessage = message || I18n.tr("setup.hydra.finish-error");
    }

    Connections {
      target: themeSession
      function onCommitted() {
        if (flow.finishState === "theme")
          flow.persistCompletion();
      }
      function onFailed(message) { flow.fail(message); }
      function onCancelled() { root.close(); }
      function onWallpaperUnavailable() {
        flow.selectedWallpaperColors = false;
        flow.previewStyle();
        flow.errorMessage = I18n.tr("setup.hydra.wallpaper-fallback");
      }
    }
    Connections {
      target: Settings
      function onSettingsSaved() {
        if (flow.finishState !== "saving")
          return;
        Settings.shouldOpenSetupWizard = Settings.data.onboardingVersion < Settings.currentOnboardingVersion;
        // Onboarding completion is independent of the cache's seen-version state.
        UpdateService.markChangelogSeen(UpdateService.currentVersion);
        UpdateService.executeSave();
        TelemetryService.init();
        root.sessionAccepted = true;
        if (!root.telemetryOnlyMode)
          themeSession.finalize();
        flow.finishState = "done";
        root.close();
      }
      function onSettingsSaveFailed(message) {
        if (flow.finishState === "saving") {
          Settings.data.general.telemetryEnabled = flow.initialTelemetry;
          Settings.data.general.umbrielKeybindIntegration = flow.initialIntegration;
          if (root.mandatorySession)
            Settings.data.onboardingVersion = 0;
          flow.fail(I18n.tr("setup.hydra.save-error", { error: message }));
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.margin2XL
      spacing: Style.margin2XL

      ColumnLayout {
        id: rail
        visible: !root.telemetryOnlyMode
        Layout.preferredWidth: flow.width < 840 * Style.uiScaleRatio ? 120 * Style.uiScaleRatio : 165 * Style.uiScaleRatio
        Layout.fillHeight: true
        spacing: Style.marginXL
        RowLayout {
          spacing: Style.marginM
          Image {
            source: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/hydra.svg")
            sourceSize.width: 32
            sourceSize.height: 32
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            fillMode: Image.PreserveAspectFit
            Accessible.ignored: true
          }
          NText { text: "Hydra"; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightBold }
        }
        Item { Layout.preferredHeight: Style.margin2XL }
        Repeater {
          model: flow.stepKeys
          delegate: RowLayout {
            required property int index
            required property string modelData
            Layout.fillWidth: true
            spacing: Style.marginM
            Rectangle {
              Layout.preferredWidth: 28 * Style.uiScaleRatio
              Layout.preferredHeight: 28 * Style.uiScaleRatio
              radius: width / 2
              color: index === flow.currentStep ? Color.mPrimary : Color.mSurfaceContainerHigh
              NIcon {
                anchors.centerIn: parent
                icon: index < flow.currentStep ? "check" : flow.stepIcons[index]
                color: index === flow.currentStep ? Color.mOnPrimary : Color.mOnSurfaceVariant
                pointSize: Style.fontSizeM
              }
            }
            NText {
              text: I18n.tr("setup.hydra.step-" + modelData)
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              color: index === flow.currentStep ? Color.mPrimary : Color.mOnSurfaceVariant
              font.weight: index === flow.currentStep ? Style.fontWeightBold : Style.fontWeightRegular
            }
          }
        }
        Item { Layout.fillHeight: true }
        NText {
          text: I18n.tr("setup.hydra.rail-note")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginL
        StackLayout {
          id: pages
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: root.telemetryOnlyMode ? 4 : flow.currentStep
          transform: Translate { id: pageOffset }
          Loader {
            id: displayLoader
            active: !root.telemetryOnlyMode
            sourceComponent: SetupDisplayStep {}
          }
          Loader {
            active: !root.telemetryOnlyMode
            sourceComponent: SetupThemeStep {
              selectedScheme: flow.selectedScheme
              darkMode: flow.selectedDark
              useWallpaperColors: flow.selectedWallpaperColors
              busy: flow.busy
              wallpaperAvailable: themeSession.wallpaperAvailable
              onSchemeSelected: name => { flow.selectedScheme = name; flow.selectedWallpaperColors = false; flow.previewStyle(); }
              onDarkModeSelected: dark => { flow.selectedDark = dark; flow.previewStyle(); }
              onWallpaperColorsSelected: enabled => { flow.selectedWallpaperColors = enabled; flow.previewStyle(); }
            }
          }
          Loader {
            active: !root.telemetryOnlyMode
            sourceComponent: SetupDiscoverStep {}
          }
          Loader {
            id: controlsLoader
            active: !root.telemetryOnlyMode
            sourceComponent: SetupControlsStep {
              useRecommended: flow.selectedRecommended
              onRecommendedSelected: enabled => flow.selectedRecommended = enabled
              onCommitted: {
                if (flow.finishState === "controls") {
                  flow.finishState = "theme";
                  themeSession.commit(flow.selectedScheme, flow.selectedDark, flow.selectedWallpaperColors, flow.selectedMaterialSpec);
                }
              }
              onFailed: message => flow.fail(message)
            }
          }
          SetupFinishStep {
            telemetryOnly: root.telemetryOnlyMode
            telemetryEnabled: flow.selectedTelemetry
            monitorSummary: flow.displayStep?.summary || ""
            styleSummary: (flow.selectedWallpaperColors ? I18n.tr("setup.hydra.wallpaper-colors") : flow.selectedScheme) + " · " + I18n.tr(flow.selectedDark ? "setup.hydra.dark" : "setup.hydra.light")
            colorsSummary: I18n.tr("setup.hydra.colors-summary", { spec: flow.selectedMaterialSpec, source: I18n.tr(flow.selectedWallpaperColors ? "setup.hydra.source-wallpaper" : "setup.hydra.source-preset") })
            controlsSummary: flow.controlsStep?.summary || ""
            onTelemetrySelected: enabled => flow.selectedTelemetry = enabled
          }
        }
        NText {
          visible: flow.errorMessage !== "" || themeSession.error !== ""
          text: flow.errorMessage || themeSession.error
          color: Color.mError
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          SetupAction {
            text: I18n.tr(root.mandatorySession ? "setup.hydra.use-defaults" : "common.cancel")
            backgroundColor: Color.mSurfaceContainerHigh
            textColor: Color.mOnSurface
            enabled: !flow.busy
            onClicked: root.mandatorySession ? flow.useDefaults() : flow.cancelSession()
          }
          Item { Layout.fillWidth: true }
          SetupAction {
            text: I18n.tr("common.back")
            visible: !root.telemetryOnlyMode && flow.currentStep > 0
            enabled: !flow.busy
            backgroundColor: Color.mSurfaceContainerHigh
            textColor: Color.mOnSurface
            onClicked: flow.changeStep(flow.currentStep - 1)
          }
          SetupAction {
            text: flow.busy ? I18n.tr("setup.hydra.working") : I18n.tr(root.telemetryOnlyMode ? "setup.hydra.privacy-confirm" : (flow.currentStep === 4 ? "setup.hydra.start" : "common.continue"))
            enabled: !flow.busy && !flow.displayBlocked && (root.telemetryOnlyMode || flow.currentStep < 3 || !controlsStep.blocked)
            onClicked: {
              if (root.telemetryOnlyMode || flow.currentStep === 4)
                flow.finish();
              else
                flow.changeStep(flow.currentStep + 1);
            }
          }
        }
      }
    }

    ParallelAnimation {
      id: pageMotion
      NumberAnimation { target: pages; property: "opacity"; from: 0.5; to: 1; duration: Style.animationFast; easing.type: Easing.OutCubic }
      NumberAnimation { target: pageOffset; property: "x"; from: 10 * Style.uiScaleRatio; to: 0; duration: Style.animationFast; easing.type: Easing.OutCubic }
    }
  }
}
