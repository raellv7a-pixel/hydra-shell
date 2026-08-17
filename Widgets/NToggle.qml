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
  readonly property bool pressed: mouseArea.pressed
  property int baseSize: Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio)
  property var defaultValue: undefined
  property string settingsPath: ""

  signal toggled(bool checked)
  signal entered
  signal exited

  Layout.fillWidth: true
  spacing: Style.marginM
  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.name: root.label
  Accessible.description: root.description
  Accessible.checked: root.checked

  readonly property bool isValueChanged: (defaultValue !== undefined) && (checked !== defaultValue)
  readonly property string indicatorTooltip: defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {
                                                                                    "value": typeof defaultValue === "boolean" ? (defaultValue ? "true" : "false") : String(defaultValue)
                                                                                  }) : ""

  NLabel {
    Layout.fillWidth: true
    label: root.label
    description: root.description
    icon: root.icon
    iconColor: root.checked ? Color.mPrimary : Color.mOnSurface
    visible: root.label !== "" || root.description !== ""
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  Rectangle {
    id: switcher

    opacity: root.enabled ? Style.opacityFull : Style.disabledContentOpacity
    Layout.alignment: Qt.AlignVCenter
    Layout.margins: Style.borderS
    implicitWidth: Math.round(root.baseSize * .85) * 2
    implicitHeight: Math.round(root.baseSize * .5) * 2
    radius: Math.min(Style.iRadiusL, height / 2)
    scale: morph.scale
    color: root.checked ? Color.mPrimary : Color.mSurfaceContainerHighest
    border.color: root.checked ? "transparent" : Color.mOutline
    border.width: root.checked ? 0 : Style.borderS

    Behavior on color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    Behavior on border.color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    NShapeMorph {
      id: morph

      enabled: root.enabled
      hovered: root.hovering
      pressed: root.pressed
      restingRadius: switcher.radius
      hoverRadius: switcher.radius
      pressedRadius: switcher.radius
    }

    NStateLayer {
      id: stateLayer

      anchors.fill: parent
      radius: switcher.radius
      enabled: root.enabled
      hovered: root.hovering
      pressed: root.pressed
      focused: root.activeFocus
      stateColor: root.checked ? Color.mOnPrimary : Color.mOnSurface
    }

    Rectangle {
      implicitWidth: Math.round(root.baseSize * 0.4) * 2
      implicitHeight: Math.round(root.baseSize * 0.4) * 2
      radius: Math.min(Style.iRadiusL, height / 2)
      color: root.checked ? Color.mOnPrimary : Color.mOnSurfaceVariant
      border.color: "transparent"
      border.width: 0
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 0
      x: root.checked ? switcher.width - width - 3 : 3

      Behavior on x {
        NAnim {
          motionType: NAnim.ExpressiveFastSpatial
        }
      }
    }

    NFocusRing {
      focusVisible: root.activeFocus
      targetRadius: switcher.radius
    }

    MouseArea {
      id: mouseArea

      enabled: root.enabled
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: {
        if (!enabled)
          return;
        hovering = true;
        root.entered();
      }
      onExited: {
        if (!enabled)
          return;
        hovering = false;
        root.exited();
      }
      onPressed: mouse => {
                   if (!root.enabled)
                   return;
                   root.forceActiveFocus();
                   stateLayer.rippleAt(mouse.x, mouse.y);
                 }
      onClicked: {
        if (!enabled)
          return;
        root.forceActiveFocus();
        root.toggled(!root.checked);
      }
    }
  }

  Keys.onReturnPressed: event => {
                          if (!root.enabled)
                          return;
                          root.toggled(!root.checked);
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         if (!root.enabled)
                         return;
                         root.toggled(!root.checked);
                         event.accepted = true;
                       }
}
