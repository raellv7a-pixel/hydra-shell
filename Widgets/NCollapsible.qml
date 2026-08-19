import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property string label: ""
  property string description: ""
  property bool expanded: false
  property real contentSpacing: Style.marginM
  property bool _userInteracted: false

  signal toggled(bool expanded)

  function toggleExpanded() {
    root._userInteracted = true;
    root.expanded = !root.expanded;
    root.toggled(root.expanded);
  }

  Layout.fillWidth: true
  spacing: 0

  // Default property to accept children
  default property alias content: contentLayout.children

  // Header with clickable area
  Rectangle {
    id: headerContainer
    Layout.fillWidth: true
    Layout.preferredHeight: headerContent.implicitHeight + Style.margin2M
    color: root.expanded ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
    radius: headerMorph.radius
    scale: headerMorph.scale
    border.color: Color.mOutline
    border.width: Style.borderS
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: root.description

    Behavior on color {
      enabled: root._userInteracted && !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    NShapeMorph {
      id: headerMorph

      hovered: headerArea.containsMouse
      pressed: headerArea.pressed
      focused: headerContainer.activeFocus
      selected: root.expanded
      restingRadius: Style.radiusControl
      hoverRadius: Style.radiusControlChecked
      pressedRadius: Style.radiusControlPressed
      selectedRadius: Style.radiusControl
    }

    NStateLayer {
      id: headerStateLayer

      anchors.fill: parent
      radius: parent.radius
      hovered: headerArea.containsMouse
      pressed: headerArea.pressed
      focused: headerContainer.activeFocus
      selected: root.expanded
      stateColor: root.expanded ? Color.mOnSecondaryContainer : Color.mPrimary
    }

    NFocusRing {
      focusVisible: headerContainer.activeFocus
      targetRadius: headerContainer.radius
    }

    MouseArea {
      id: headerArea
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onPressed: mouse => {
                   headerContainer.forceActiveFocus();
                   headerStateLayer.rippleAt(mouse.x, mouse.y);
                 }
      onClicked: root.toggleExpanded()

      enabled: true
    }

    RowLayout {
      id: headerContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      // Expand/collapse icon with rotation animation
      NIcon {
        id: chevronIcon
        icon: "chevron-right"
        pointSize: Style.fontSizeL
        color: root.expanded ? Color.mOnSecondaryContainer : Color.mOnSurface
        Layout.alignment: Qt.AlignVCenter

        rotation: root.expanded ? 90 : 0
        Behavior on rotation {
          enabled: root._userInteracted
          NAnim {
            motionType: NAnim.EmphasizedSpatial
          }
        }

        Behavior on color {
          enabled: root._userInteracted && !Color.isTransitioning
          NColorAnimation {
            motionType: NColorAnimation.Standard
          }
        }
      }

      // Header text content - properly contained
      RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginL

        NText {
          text: root.label
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: root.expanded ? Color.mOnSecondaryContainer : Color.mOnSurface
          wrapMode: Text.WordWrap

          Behavior on color {
            enabled: root._userInteracted && !Color.isTransitioning
            NColorAnimation {
              motionType: NColorAnimation.Standard
            }
          }
        }

        NText {
          text: root.description
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightRegular
          color: root.expanded ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          visible: root.description !== ""
          opacity: 0.87

          Behavior on color {
            enabled: root._userInteracted && !Color.isTransitioning
            NColorAnimation {
              motionType: NColorAnimation.Standard
            }
          }
        }
      }
    }
    Keys.onReturnPressed: event => {
                            root.toggleExpanded();
                            event.accepted = true;
                          }
    Keys.onSpacePressed: event => {
                           root.toggleExpanded();
                           event.accepted = true;
                         }
  }

  // Collapsible content with Material 3 styling
  Rectangle {
    id: contentContainer
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS

    visible: root.expanded || opacity > 0
    color: Color.mSurfaceContainerLow
    radius: Style.radiusControl
    border.color: Color.mOutline
    border.width: Style.borderS

    // Dynamic height based on content
    Layout.preferredHeight: expanded ? contentLayout.implicitHeight + Style.margin2L : 0

    // Smooth height animation
    Behavior on Layout.preferredHeight {
      enabled: root._userInteracted
      NAnim {
        motionType: NAnim.EmphasizedSpatial
      }
    }

    // Content layout
    ColumnLayout {
      id: contentLayout
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: root.contentSpacing
    }

    // Fade in animation for content
    opacity: root.expanded ? 1.0 : 0.0
    Behavior on opacity {
      enabled: root._userInteracted
      NAnim {
        duration: Style.motionDurationDefaultEffects
        motionType: NAnim.StandardEffects
      }
    }
  }
}
