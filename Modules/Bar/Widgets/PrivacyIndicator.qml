import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: buildTooltip()

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
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

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  readonly property bool hideInactive: widgetSettings.hideInactive !== undefined ? widgetSettings.hideInactive : widgetMetadata.hideInactive

  readonly property bool micActive: PrivacyIndicatorService.micActive
  readonly property bool camActive: PrivacyIndicatorService.camActive
  readonly property bool scrActive: PrivacyIndicatorService.scrActive
  readonly property var micApps: PrivacyIndicatorService.micApps
  readonly property var camApps: PrivacyIndicatorService.camApps
  readonly property var scrApps: PrivacyIndicatorService.scrApps
  readonly property string cameraDetectionState: PrivacyIndicatorService.cameraDetectionState

  readonly property color inactiveColor: Qt.alpha(Color.mOnSurfaceVariant, 0.3)
  readonly property color micColor: micActive ? Color.mPrimary : inactiveColor
  readonly property color camColor: camActive ? Color.mPrimary : inactiveColor
  readonly property color scrColor: scrActive ? Color.mPrimary : inactiveColor

  readonly property bool isPrivacyVisible: !hideInactive || micActive || camActive || scrActive

  // Content dimensions for implicit sizing
  readonly property real contentWidth: isVertical ? capsuleHeight : Math.round(layout.implicitWidth + Style.margin2M)
  readonly property real contentHeight: isVertical ? Math.round(layout.implicitHeight + Style.margin2M) : capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  visible: root.isPrivacyVisible
  opacity: root.isPrivacyVisible ? 1.0 : 0.0

  function buildTooltip() {
    var parts = [];

    if (micActive) {
      parts.push(micApps.length > 0 ? I18n.tr("tooltips.privacy-indicator-mic", {
                                                "apps": micApps.join(", ")
                                              }) : I18n.tr("tooltips.privacy-indicator-mic-active"));
    }

    if (camActive) {
      parts.push(camApps.length > 0 ? I18n.tr("tooltips.privacy-indicator-cam", {
                                                "apps": camApps.join(", ")
                                              }) : I18n.tr("tooltips.privacy-indicator-cam-active"));
    }

    if (scrActive) {
      parts.push(scrApps.length > 0 ? I18n.tr("tooltips.privacy-indicator-screen", {
                                                "apps": scrApps.join(", ")
                                              }) : I18n.tr("tooltips.privacy-indicator-screen-active"));
    }

    if (cameraDetectionState === "limited")
      parts.push(I18n.tr("tooltips.privacy-indicator-video-limited"));
    else if (cameraDetectionState === "timeout" || cameraDetectionState === "unavailable")
      parts.push(I18n.tr("tooltips.privacy-indicator-camera-unavailable"));

    return parts.length > 0 ? parts.join("\n") : I18n.tr("tooltips.privacy-indicator-idle");
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]
    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  // Visual capsule centered in parent
  Rectangle {
    id: visualCapsule
    anchors.centerIn: parent
    color: Style.capsuleColor
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusCapsule
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    NStateLayer {
      id: privacyStateLayer

      anchors.fill: parent
      hovered: privacyMouseArea.containsMouse
      pressed: privacyMouseArea.pressed
      focused: root.activeFocus
      stateColor: Color.mTertiary
      radius: parent.radius
    }

    Item {
      id: layout

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: iconsLayout.implicitWidth
      implicitHeight: iconsLayout.implicitHeight

      GridLayout {
        id: iconsLayout

        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        rowSpacing: Style.marginXS
        columnSpacing: Style.marginXS

        NIcon {
          visible: root.micActive || !root.hideInactive
          icon: root.micActive ? "microphone" : "microphone-off"
          color: root.micColor
        }
        NIcon {
          visible: root.camActive || !root.hideInactive
          icon: root.camActive ? "camera" : "camera-off"
          color: root.camColor
        }
        NIcon {
          visible: root.scrActive || !root.hideInactive
          icon: root.scrActive ? "screen-share" : "screen-share-off"
          color: root.scrColor
        }
      }
    }
  }

  NFocusRing {
    anchors.fill: visualCapsule
    focusVisible: root.activeFocus
    targetRadius: visualCapsule.radius
  }

  MouseArea {
    id: privacyMouseArea
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    hoverEnabled: true
    onPressed: mouse => {
                 root.forceActiveFocus();
                 const point = mapToItem(privacyStateLayer, mouse.x, mouse.y);
                 privacyStateLayer.rippleAt(point.x, point.y);
               }

    onClicked: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   PanelService.showContextMenu(contextMenu, root, screen);
                 }
               }

    onEntered: {
      var tooltipText = root.buildTooltip();
      if (tooltipText) {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection(root.screenName));
      }
    }
    onExited: TooltipService.hide()
  }

  Keys.onReturnPressed: event => {
                          PanelService.showContextMenu(contextMenu, root, screen);
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         PanelService.showContextMenu(contextMenu, root, screen);
                         event.accepted = true;
                       }
}
