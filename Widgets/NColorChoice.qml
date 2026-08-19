import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

RowLayout {
  id: root

  property string label: I18n.tr("common.select-color")
  property string description: I18n.tr("common.select-color-description")
  property string tooltip: ""
  property string currentKey: ""
  property var defaultValue: undefined
  property var noneColor: undefined      // color declared as var so we can nullify
  property var noneOnColor: undefined    // color declared as var so we can nullify

  readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey !== defaultValue)
  readonly property string indicatorTooltip: {
    I18n.tr("panels.indicator.default-value", {
              "value": defaultValue === "" ? "(empty)" : String(defaultValue)
            });
  }

  readonly property int diameter: Style.baseWidgetSize * 0.9 * Style.uiScaleRatio

  signal selected(string key)

  NLabel {
    label: root.label
    description: root.description
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  RowLayout {
    id: colourRow

    opacity: enabled ? 1.0 : 0.6
    Layout.minimumWidth: root.diameter * Color.colorKeyModel.length

    Repeater {
      model: Color.colorKeyModel

      Rectangle {
        id: colorCircle

        property bool isSelected: root.currentKey === modelData.key
        property bool isHovered: circleMouseArea.containsMouse
        readonly property bool pressed: circleMouseArea.pressed

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: root.diameter
        implicitHeight: root.diameter
        radius: root.diameter * 0.5
        scale: circleMorph.scale
        activeFocusOnTab: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData.name
        Accessible.checked: colorCircle.isSelected
        color: (modelData.key === "none" && root.noneColor !== undefined) ? root.noneColor : Color.resolveColorKey(modelData.key)
        border.color: (isSelected || isHovered) ? Color.mOnSurface : Color.mOutline
        border.width: Style.borderM

        NShapeMorph {
          id: circleMorph

          enabled: root.enabled
          hovered: colorCircle.isHovered
          pressed: colorCircle.pressed
          selected: colorCircle.isSelected
          restingRadius: colorCircle.width / 2
          hoverRadius: colorCircle.width / 2
          pressedRadius: colorCircle.width / 2
          selectedRadius: colorCircle.width / 2
        }

        NStateLayer {
          id: circleStateLayer

          anchors.fill: parent
          radius: colorCircle.radius
          enabled: root.enabled
          hovered: colorCircle.isHovered
          pressed: colorCircle.pressed
          focused: colorCircle.activeFocus
          selected: colorCircle.isSelected
          stateColor: Color.resolveOnColorKey(modelData.key)
        }

        MouseArea {
          id: circleMouseArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          enabled: root.enabled
          onEntered: TooltipService.show(parent, modelData.name)
          onExited: TooltipService.hide()
          onPressed: mouse => {
                       colorCircle.forceActiveFocus();
                       circleStateLayer.rippleAt(mouse.x, mouse.y);
                     }
          onClicked: {
            root.currentKey = modelData.key;
            root.selected(modelData.key);
          }
        }

        Keys.onReturnPressed: event => {
                                if (!root.enabled)
                                return;
                                root.currentKey = modelData.key;
                                root.selected(modelData.key);
                                event.accepted = true;
                              }
        Keys.onSpacePressed: event => {
                               if (!root.enabled)
                               return;
                               root.currentKey = modelData.key;
                               root.selected(modelData.key);
                               event.accepted = true;
                             }

        NIcon {
          anchors.centerIn: parent
          icon: "check"
          pointSize: Math.max(Style.fontSizeXS, colorCircle.width * 0.4)
          color: (modelData.key === "none" && root.noneOnColor !== undefined) ? root.noneOnColor : Color.resolveOnColorKey(modelData.key)
          font.weight: Style.fontWeightBold
          visible: colorCircle.isSelected
        }

        NFocusRing {
          focusVisible: colorCircle.activeFocus
          targetRadius: colorCircle.radius
        }

        Behavior on border.color {
          enabled: !Color.isTransitioning
          NColorAnimation {
            motionType: NColorAnimation.Standard
          }
        }
      }
    }
  }
}
