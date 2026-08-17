import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  // The GPU state is global, while the level and output port belong to this widget instance.
  readonly property bool vibranceEnabled: Settings.data.nvibrant.enabled
  readonly property int vibranceValue: widgetSettings.vibranceValue !== undefined ? widgetSettings.vibranceValue : Settings.data.nvibrant.vibranceValue
  readonly property int displayIndex: widgetSettings.displayIndex !== undefined ? widgetSettings.displayIndex : Settings.data.nvibrant.displayIndex
  readonly property bool commandRunning: availabilityCheck.running || applyProcess.running
  property bool pendingEnabled: false

  icon: "contrast"
  tooltipText: vibranceEnabled ? I18n.tr("tooltips.disable-vibrance") : I18n.tr("tooltips.enable-vibrance")
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: root.vibranceEnabled ? Color.mPrimary : Color.resolveColorKey(iconColorKey)
  onClicked: root.toggle()

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  function buildCommand(value) {
    const command = ["nvibrant"];
    // nvibrant arguments map to physical output ports; zero-fill ports before
    // the configured one (stored 1-based for the settings UI).
    for (let i = 1; i < root.displayIndex; ++i)
      command.push("0");
    command.push(String(value));
    return command;
  }

  function toggle() {
    if (root.commandRunning)
      return;

    root.pendingEnabled = !root.vibranceEnabled;
    availabilityCheck.running = true;
  }

  Process {
    id: availabilityCheck
    running: false
    command: ["sh", "-c", "command -v nvibrant >/dev/null 2>&1"]

    onExited: exitCode => {
      if (exitCode === 0) {
        applyProcess.running = true;
      } else {
        ToastService.showError(I18n.tr("bar.nvibrant.missing-binary-title"), I18n.tr("bar.nvibrant.missing-binary-description"));
      }
    }
  }

  Process {
    id: applyProcess
    running: false
    command: root.buildCommand(root.pendingEnabled ? root.vibranceValue : 0)

    onExited: exitCode => {
      if (exitCode === 0) {
        Settings.data.nvibrant.enabled = root.pendingEnabled;
      } else {
        ToastService.showError(I18n.tr("bar.nvibrant.apply-failed-title"), I18n.tr("bar.nvibrant.apply-failed-description", {
                                                                                     "code": exitCode
                                                                                   }));
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": root.vibranceEnabled ? I18n.tr("tooltips.disable-vibrance") : I18n.tr("tooltips.enable-vibrance"),
        "action": "toggle",
        "icon": root.vibranceEnabled ? "eye-off" : "eye"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "toggle") {
        root.toggle();
      } else if (action === "widget-settings") {
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
