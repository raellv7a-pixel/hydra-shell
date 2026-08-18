import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Panels.Tamagotchi
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
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
      const widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length)
        return widgets[sectionWidgetIndex];
    }
    return {};
  }

  readonly property bool showPercentage: widgetSettings.showPercentage !== undefined ? widgetSettings.showPercentage : widgetMetadata.showPercentage
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property int roundedNeed: Math.round(TamagotchiService.lowestNeed)
  readonly property string stateLabel: I18n.tr("tamagotchi.states." + TamagotchiService.petState)
  readonly property string tooltipText: I18n.tr("tamagotchi.bar.tooltip", {
                                                  "state": stateLabel,
                                                  "need": roundedNeed
                                                })

  implicitWidth: barIsVertical ? capsuleHeight : visualRow.implicitWidth + Style.margin2S
  implicitHeight: capsuleHeight
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: tooltipText

  Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                      root.togglePanel();
                      event.accepted = true;
                    }
                  }

  function togglePanel() {
    const panel = PanelService.getPanel("tamagotchiPanel", screen);
    if (panel)
      panel.toggle(root);
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("tamagotchi.actions.open"),
        "action": "open",
        "icon": "heart"
      },
      {
        "label": TamagotchiService.sleeping ? I18n.tr("tamagotchi.actions.wake") : I18n.tr("tamagotchi.actions.rest"),
        "action": "rest",
        "icon": TamagotchiService.sleeping ? "sun" : "moon"
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
                   if (action === "open")
                   root.togglePanel();
                   else if (action === "rest")
                   TamagotchiService.rest();
                   else if (action === "widget-settings")
                   BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                 }
  }

  Rectangle {
    id: capsule
    anchors.centerIn: parent
    width: root.implicitWidth
    height: root.implicitHeight
    radius: Style.radiusCapsule
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    NStateLayer {
      id: tamagotchiStateLayer

      anchors.fill: parent
      hovered: mouseArea.containsMouse
      pressed: mouseArea.pressed
      focused: root.activeFocus
      stateColor: Color.mPrimary
      radius: parent.radius
    }

    Row {
      id: visualRow
      anchors.centerIn: parent
      spacing: root.showPercentage && !root.barIsVertical ? Style.marginXS : 0

      PetSprite {
        spriteSize: Math.max(18, root.capsuleHeight - Style.marginXS * 2)
      }

      NText {
        visible: root.showPercentage && !root.barIsVertical
        anchors.verticalCenter: parent.verticalCenter
        text: root.roundedNeed + "%"
        pointSize: Style.fontSizeXXS
        color: root.roundedNeed < 20 ? Color.mError : Color.mOnSurface
      }
    }
  }

  NFocusRing {
    anchors.fill: capsule
    focusVisible: root.activeFocus
    targetRadius: capsule.radius
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => {
                 root.forceActiveFocus();
                 const point = mapToItem(tamagotchiStateLayer, mouse.x, mouse.y);
                 tamagotchiStateLayer.rippleAt(point.x, point.y);
               }

    onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
    onExited: TooltipService.hide()
    onClicked: mouse => {
                 TooltipService.hide();
                 if (mouse.button === Qt.RightButton)
                 PanelService.showContextMenu(contextMenu, root, screen);
                 else
                 root.togglePanel();
               }
  }
}
