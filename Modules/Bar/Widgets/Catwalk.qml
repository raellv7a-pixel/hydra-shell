import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: tooltipText

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
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
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  readonly property real minimumThreshold: widgetSettings.minimumThreshold !== undefined ? widgetSettings.minimumThreshold : widgetMetadata.minimumThreshold

  // --- Catwalk animation logic ---
  readonly property real cpuUsage: SystemStatService.cpuUsage
  readonly property bool isRunning: cpuUsage >= minimumThreshold

  readonly property var activeIcons: ["my-active-0-symbolic.svg", "my-active-1-symbolic.svg", "my-active-2-symbolic.svg", "my-active-3-symbolic.svg", "my-active-4-symbolic.svg"]
  readonly property var idleIcons: ["my-idle-0-symbolic.svg", "my-idle-1-symbolic.svg", "my-idle-2-symbolic.svg", "my-idle-3-symbolic.svg"]

  property int frameIndex: 0
  property int idleFrameIndex: 0

  readonly property url currentIconSource: root.isRunning ? Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Icons/Catwalk/" + root.activeIcons[root.frameIndex % root.activeIcons.length]) : Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Icons/Catwalk/" + root.idleIcons[root.idleFrameIndex % root.idleIcons.length])

  readonly property string tooltipText: root.isRunning ? I18n.tr("tooltips.catwalk-running") : I18n.tr("tooltips.catwalk-sleeping")

  readonly property real contentWidth: barIsVertical ? capsuleHeight : Math.round(capsuleHeight + Style.marginXS * 2)
  readonly property real contentHeight: capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Timer {
    interval: Math.max(30, 200 - root.cpuUsage * 1.7)
    running: root.isRunning
    repeat: true
    onTriggered: root.frameIndex = (root.frameIndex + 1) % root.activeIcons.length
  }

  Timer {
    interval: 400
    running: !root.isRunning
    repeat: true
    onTriggered: root.idleFrameIndex = (root.idleFrameIndex + 1) % root.idleIcons.length
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: Style.capsuleColor
    radius: Style.radiusCapsule
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    NStateLayer {
      id: catwalkStateLayer

      anchors.fill: parent
      hovered: mouseArea.containsMouse
      pressed: mouseArea.pressed
      focused: root.activeFocus
      stateColor: Color.mOnSurface
      radius: parent.radius
    }

    Image {
      id: iconImage
      source: root.currentIconSource
      x: Style.pixelAlignCenter(parent.width, width)
      y: Style.pixelAlignCenter(parent.height, height)

      width: Style.toOdd(visualCapsule.width - Style.marginXS * 2)
      height: width

      // Render SVG at exact target size for crisp output
      sourceSize: Qt.size(width, height)
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: false

      // This enables the "mask" behavior to recolor the icon
      layer.enabled: true
      layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: Settings.data.colorSchemes.darkMode ? "white" : "black"
      }
    }
  }

  NFocusRing {
    anchors.fill: visualCapsule
    focusVisible: root.activeFocus
    targetRadius: visualCapsule.radius
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onPressed: mouse => {
                 root.forceActiveFocus();
                 const point = mapToItem(catwalkStateLayer, mouse.x, mouse.y);
                 catwalkStateLayer.rippleAt(point.x, point.y);
               }
    onEntered: {
      TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName));
    }
    onExited: {
      TooltipService.hide();
    }
    onClicked: mouse => {
                 TooltipService.hide();
                 if (mouse.button === Qt.RightButton) {
                   PanelService.showContextMenu(contextMenu, root, screen);
                 }
               }
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
