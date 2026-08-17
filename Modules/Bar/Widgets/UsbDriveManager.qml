import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length)
        return widgets[sectionWidgetIndex];
    }
    return {};
  }

  readonly property bool hideWhenEmpty: widgetSettings.hideWhenEmpty !== undefined ? widgetSettings.hideWhenEmpty : widgetMetadata.hideWhenEmpty
  readonly property bool showBadge: widgetSettings.showBadge !== undefined ? widgetSettings.showBadge : widgetMetadata.showBadge
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property bool hasDevices: UsbDriveService.devices.length > 0
  readonly property bool hasMountedDevices: UsbDriveService.mountedCount > 0

  visible: !hideWhenEmpty || hasDevices
  icon: "usb"
  tooltipText: {
    if (!UsbDriveService.dependenciesChecked)
      return I18n.tr("usb-drive-manager.bar.checking");
    if (!UsbDriveService.lsblkAvailable)
      return I18n.tr("usb-drive-manager.bar.unavailable");
    if (UsbDriveService.devices.length === 0)
      return I18n.tr("usb-drive-manager.bar.empty");
    return I18n.tr("usb-drive-manager.bar.summary", {
                     "count": UsbDriveService.devices.length,
                     "mounted": UsbDriveService.mountedCount
                   });
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: hasMountedDevices ? Color.mPrimary : Style.capsuleColor
  colorFg: hasMountedDevices ? Color.mOnPrimary : Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    UsbDriveService.refreshDevices();
    PanelService.getPanel("usbDriveManagerPanel", screen)?.toggle(root);
  }

  onRightClicked: PanelService.showContextMenu(contextMenu, root, screen)

  Rectangle {
    visible: root.showBadge && UsbDriveService.mountedCount > 0
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 1
    width: Math.max(badgeLabel.implicitWidth + 6, 14)
    height: 14
    radius: height / 2
    color: root.hasMountedDevices ? Color.mOnPrimary : Color.mPrimary

    NText {
      id: badgeLabel
      anchors.centerIn: parent
      text: String(UsbDriveService.mountedCount)
      pointSize: Style.fontSizeXXS
      font.weight: Style.fontWeightBold
      color: root.hasMountedDevices ? Color.mPrimary : Color.mOnPrimary
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("usb-drive-manager.actions.open-panel"),
        "action": "open-panel",
        "icon": "usb"
      },
      {
        "label": I18n.tr("usb-drive-manager.actions.refresh"),
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": I18n.tr("usb-drive-manager.actions.unmount-all"),
        "action": "unmount-all",
        "icon": "plug-connected-x"
      },
      {
        "label": I18n.tr("usb-drive-manager.actions.eject-all"),
        "action": "eject-all",
        "icon": "player-eject"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);
                   if (action === "open-panel") {
                     UsbDriveService.refreshDevices();
                     PanelService.getPanel("usbDriveManagerPanel", screen)?.toggle(root);
                   } else if (action === "refresh") {
                     UsbDriveService.refreshDevices();
                   } else if (action === "unmount-all") {
                     UsbDriveService.unmountAll();
                   } else if (action === "eject-all") {
                     UsbDriveService.ejectAll();
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }
}
