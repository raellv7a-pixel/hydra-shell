import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
  id: root

  property string label: ""
  property string description: ""
  property string icon: ""
  property bool checked: false
  property bool hovering: false
  property int baseSize: Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio)
  property var defaultValue: undefined
  property string settingsPath: ""

  signal toggled(bool checked)
  signal entered
  signal exited

  Layout.fillWidth: true
  spacing: Style.marginM
  activeFocusOnTab: false

  readonly property bool isValueChanged: (defaultValue !== undefined) && (checked !== defaultValue)
  readonly property string indicatorTooltip: defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {
                                                                                    "value": typeof defaultValue === "boolean" ? (defaultValue ? "true" : "false") : String(defaultValue)
                                                                                  }) : ""

  NLabel {
    Layout.fillWidth: true
    label: root.label
    description: root.description
    icon: root.icon
    iconColor: root.checked ? HydraColor.mPrimary : HydraColor.mOnSurface
    visible: root.label !== "" || root.description !== ""
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  NStateLayer {
    id: switcher

    opacity: enabled ? 1.0 : 0.6
    Layout.alignment: Qt.AlignVCenter
    Layout.margins: Style.borderS
    implicitWidth: Math.round(root.baseSize * .85) * 2
    implicitHeight: Math.round(root.baseSize * .5) * 2
    radius: Math.min(Style.iRadiusL, height / 2)
    baseColor: root.checked ? HydraColor.mPrimary : HydraColor.mSurfaceContainerHighest
    stateColor: root.checked ? HydraColor.mOnPrimary : HydraColor.mOnSurface
    focusColor: root.checked ? HydraColor.mOnPrimary : HydraColor.mPrimary
    hovering: root.hovering
    pressed: switchMouse.pressed
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.label
    Accessible.description: root.description
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onPressAction: root.toggled(!root.checked)
    border.color: root.checked ? "transparent" : HydraColor.mOutline
    border.width: root.checked ? 0 : Style.borderS

    Rectangle {
      implicitWidth: Math.round(root.baseSize * 0.4) * 2
      implicitHeight: Math.round(root.baseSize * 0.4) * 2
      radius: Math.min(Style.iRadiusL, height / 2)
      color: root.checked ? HydraColor.mOnPrimary : HydraColor.mOnSurfaceVariant
      border.color: "transparent"
      border.width: 0
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 0
      x: root.checked ? switcher.width - width - 3 : 3

      Behavior on x {
        NumberAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }

    MouseArea {
      id: switchMouse
      enabled: root.enabled
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: {
        if (!enabled)
          return;
        root.hovering = true;
        root.entered();
      }
      onExited: {
        if (!enabled)
          return;
        root.hovering = false;
        root.exited();
      }
      onClicked: {
        if (!enabled)
          return;
        switcher.forceActiveFocus(Qt.MouseFocusReason);
        root.toggled(!root.checked);
      }
    }
  }

  Keys.onReturnPressed: root.toggled(!root.checked)
  Keys.onSpacePressed: root.toggled(!root.checked)
}
