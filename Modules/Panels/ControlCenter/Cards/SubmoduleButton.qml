import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Small pill button used by several cards to jump into a detail view
// ("Details" chevron on Performance/System Controls/Notifications/Calendar).
Item {
  id: submoduleButton

  required property var panelRoot

  property string styleKey: panelRoot.inheritedStyleKey(parent)
  property string labelText: panelRoot.tr("openDetails")
  property string iconName: "chevron-right"
  property string targetView: ""
  property var tooltipText: panelRoot.tr("details")

  Layout.preferredWidth: Math.max(Math.round(78 * panelRoot.panelUnit), contentRow.implicitWidth + Style.marginM * 2)
  Layout.preferredHeight: Math.round(30 * panelRoot.panelUnit)
  implicitWidth: Layout.preferredWidth
  implicitHeight: Layout.preferredHeight
  width: implicitWidth
  height: implicitHeight
  scale: submoduleTap.pressed ? 0.96 : (submoduleHover.hovered || activeFocus ? 1.025 : 1)
  transformOrigin: Item.Center
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: labelText

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: submoduleHover.hovered || submoduleButton.activeFocus ? panelRoot.componentButtonBackground(submoduleButton.styleKey) : panelRoot.m3PrimaryContainer
    border.width: submoduleButton.activeFocus ? Style.borderM : 0
    border.color: panelRoot.componentAccent(submoduleButton.styleKey)

    Behavior on color {
      ColorAnimation {
        duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginXXS

      NText {
        text: submoduleButton.labelText
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightSemiBold
        color: submoduleHover.hovered || submoduleButton.activeFocus ? panelRoot.componentButtonText(submoduleButton.styleKey) : panelRoot.componentText(submoduleButton.styleKey, true)
      }

      NIcon {
        icon: submoduleButton.iconName
        pointSize: Style.fontSizeS
        color: submoduleHover.hovered || submoduleButton.activeFocus ? panelRoot.componentButtonText(submoduleButton.styleKey) : panelRoot.componentAccent(submoduleButton.styleKey)
      }
    }
  }

  HoverHandler {
    id: submoduleHover
  }

  TapHandler {
    id: submoduleTap
    onTapped: panelRoot.activeDetailView = submoduleButton.targetView
  }

  Behavior on scale {
    ScaleAnimator {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
      easing.type: submoduleTap.pressed ? Easing.OutCubic : Easing.OutBack
    }
  }

  Keys.onReturnPressed: panelRoot.activeDetailView = submoduleButton.targetView
  Keys.onSpacePressed: panelRoot.activeDetailView = submoduleButton.targetView

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.NoButton
    onEntered: TooltipService.show(parent, submoduleButton.tooltipText)
    onExited: TooltipService.hide()
  }
}
