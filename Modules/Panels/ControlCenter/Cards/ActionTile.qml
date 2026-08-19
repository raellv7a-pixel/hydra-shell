import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI
DashboardCard {
  id: actionTile

  styleKey: "quickActions"

  property string labelText: ""
  property string detailText: ""
  property string iconName: ""
  property string secondaryIcon: ""
  property string secondaryTooltip: ""
  property var hoverTooltip: null
  property string hoverTooltipDirection: "right"
  property bool active: false
  signal triggered
  signal secondaryTriggered

  Layout.fillWidth: true
  Layout.preferredHeight: Math.round(64 * panelRoot.panelUnit)
  color: active ? panelRoot.m3PrimaryContainer : panelRoot.componentColor(styleKey, "buttonBackground", panelRoot.m3SurfaceContainerHigh)
  radius: Style.iRadiusL
  border.color: activeFocus ? panelRoot.componentAccent(styleKey) : "transparent"
  border.width: activeFocus ? Style.borderM : 0
  scale: actionTap.pressed ? 0.975 : (hoverHandler.hovered || activeFocus ? 1.012 : 1)
  transformOrigin: Item.Center
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: labelText
  Accessible.description: detailText

  Behavior on color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Behavior on border.color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Behavior on scale {
    ScaleAnimator {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
      easing.type: actionTap.pressed ? Easing.OutCubic : Easing.OutBack
    }
  }

  HoverHandler {
    id: hoverHandler

    onHoveredChanged: {
      const hasTooltip = actionTile.hoverTooltip !== null && actionTile.hoverTooltip !== "" && actionTile.hoverTooltip.length !== 0;
      if (hovered && hasTooltip)
        TooltipService.show(actionTile, actionTile.hoverTooltip, actionTile.hoverTooltipDirection);
      else
        TooltipService.hide(actionTile);
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginXS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: iconName
        color: active ? panelRoot.componentAccent(actionTile.styleKey) : panelRoot.componentText(actionTile.styleKey, false)
        pointSize: Style.fontSizeXL
        scale: active ? 1.08 : 1

        Behavior on scale {
          ScaleAnimator {
            duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
            easing.type: Easing.OutBack
          }
        }
      }

      NText {
        Layout.fillWidth: true
        text: labelText
        color: panelRoot.componentText(actionTile.styleKey, true)
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }
    }

    RowLayout {
      Layout.fillWidth: true
      opacity: 1
      enabled: true
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: detailText
        pointSize: Style.fontSizeXS
        color: panelRoot.componentText(actionTile.styleKey, false)
        elide: Text.ElideRight
      }

      NIconButton {
        id: secBtn
        visible: secondaryIcon !== ""
        icon: secondaryIcon
        baseSize: Math.round(24 * panelRoot.panelUnit)
        tooltipText: secondaryTooltip
        colorBg: "transparent"
        colorBgHover: panelRoot.componentButtonBackground(actionTile.styleKey)
        colorFg: panelRoot.componentText(actionTile.styleKey, false)
        colorFgHover: panelRoot.componentButtonText(actionTile.styleKey)
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: actionTile.secondaryTriggered()
      }
    }
  }

  TapHandler {
    id: actionTap
    onTapped: eventPoint => {
                if (secBtn.visible) {
                  const pt = secBtn.mapFromItem(actionTile, eventPoint.position);
                  if (pt.x >= 0 && pt.x <= secBtn.width && pt.y >= 0 && pt.y <= secBtn.height)
                  return;
                }
                parent.triggered();
              }
  }

  Keys.onReturnPressed: actionTile.triggered()
  Keys.onSpacePressed: actionTile.triggered()
}
