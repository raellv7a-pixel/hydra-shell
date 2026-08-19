import QtQuick
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

Item {
  id: pillContainer
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: workspace.name || workspace.idx.toString()

  required property var workspace
  required property bool isVertical

  // These must be provided by the parent Workspace widget
  required property real baseDimensionRatio
  required property real capsuleHeight
  required property real barHeight
  required property string labelMode
  required property int fontWeight
  required property int characterCount
  required property real textRatio
  required property bool showLabelsOnlyWhenOccupied
  required property string focusedColor
  required property string occupiedColor
  required property string emptyColor
  required property real masterProgress
  required property bool effectsActive
  required property color effectColor
  required property var getWorkspaceWidth
  required property var getWorkspaceHeight

  // Fixed dimension (cross-axis) for visual pill
  readonly property real fixedDimension: Style.toOdd(capsuleHeight * baseDimensionRatio)

  // Animated pill dimensions (for visual pill, not container)
  property real pillWidth: isVertical ? fixedDimension : getWorkspaceWidth(workspace, false)
  property real pillHeight: isVertical ? getWorkspaceHeight(workspace, false) : fixedDimension

  // Container uses full barHeight on cross-axis for larger click area
  width: isVertical ? barHeight : getWorkspaceWidth(workspace, false)
  height: isVertical ? getWorkspaceHeight(workspace, false) : barHeight

  states: [
    State {
      name: "active"
      when: workspace.isActive
      PropertyChanges {
        target: pillContainer
        width: isVertical ? barHeight : getWorkspaceWidth(workspace, true)
        height: isVertical ? getWorkspaceHeight(workspace, true) : barHeight
        pillWidth: isVertical ? fixedDimension : getWorkspaceWidth(workspace, true)
        pillHeight: isVertical ? getWorkspaceHeight(workspace, true) : fixedDimension
      }
    }
  ]

  Rectangle {
    id: pill
    width: pillContainer.pillWidth
    height: pillContainer.pillHeight
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    radius: Style.radiusCapsule
    z: 0

    color: {
      if (workspace.isFocused)
        return Color.resolveColorKey(focusedColor);
      if (workspace.isUrgent)
        return Color.mError;
      if (workspace.isOccupied)
        return Color.resolveColorKey(occupiedColor);
      return Qt.alpha(Color.resolveColorKey(emptyColor), 0.3);
    }

    NStateLayer {
      id: workspaceStateLayer

      anchors.fill: parent
      hovered: pillMouseArea.containsMouse
      pressed: pillMouseArea.pressed
      focused: pillContainer.activeFocus
      selected: workspace.isFocused
      stateColor: workspace.isFocused ? Color.resolveOnColorKey(focusedColor) : Color.mOnSurface
      radius: parent.radius
    }

    Loader {
      active: (labelMode !== "none") && (!showLabelsOnlyWhenOccupied || workspace.isOccupied || workspace.isFocused)
      anchors.fill: parent
      sourceComponent: Component {
        NText {
          text: {
            if (workspace.name && workspace.name.length > 0) {
              if (labelMode === "name") {
                return workspace.name.substring(0, characterCount);
              }
              if (labelMode === "index+name") {
                // Vertical mode: compact format (no space, first char only)
                // Horizontal mode: full format (space, more chars)
                if (isVertical) {
                  return workspace.idx.toString() + workspace.name.substring(0, 1);
                }
                return workspace.idx.toString() + " " + workspace.name.substring(0, characterCount);
              }
            }
            return workspace.idx.toString();
          }
          family: Settings.data.ui.fontFixed
          // Size based on the fixed dimension (cross-axis) of the visual pill
          pointSize: (isVertical ? pillContainer.pillWidth : pillContainer.pillHeight) * textRatio
          applyUiScale: false
          font.capitalization: Font.AllUppercase
          font.weight: fontWeight
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.Wrap
          color: {
            if (workspace.isFocused)
              return Color.resolveOnColorKey(focusedColor);
            if (workspace.isUrgent)
              return Color.mOnError;
            if (workspace.isOccupied)
              return Color.resolveOnColorKey(occupiedColor);
            return Color.resolveOnColorKey(emptyColor);
          }

          Behavior on color {
            enabled: !Color.isTransitioning
            NColorAnimation {
              duration: Style.motionDurationFastEffects
            }
          }
        }
      }
    }

    // Material 3-inspired smooth animations
    Behavior on scale {
      NAnim {
        motionType: NAnim.ExpressiveFastSpatial
      }
    }
    Behavior on color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        duration: Style.motionDurationFastEffects
      }
    }
    Behavior on opacity {
      NAnim {
        duration: Style.motionDurationFastEffects
        motionType: NAnim.StandardEffects
      }
    }
  }

  NFocusRing {
    anchors.fill: pill
    focusVisible: pillContainer.activeFocus
    targetRadius: pill.radius
  }

  Behavior on width {
    NAnim {
      motionType: NAnim.EmphasizedSpatial
    }
  }
  Behavior on height {
    NAnim {
      motionType: NAnim.EmphasizedSpatial
    }
  }
  Behavior on pillWidth {
    NAnim {
      motionType: NAnim.EmphasizedSpatial
    }
  }
  Behavior on pillHeight {
    NAnim {
      motionType: NAnim.EmphasizedSpatial
    }
  }

  // Full-height click area
  MouseArea {
    id: pillMouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onPressed: mouse => {
                 pillContainer.forceActiveFocus();
                 const point = mapToItem(workspaceStateLayer, mouse.x, mouse.y);
                 workspaceStateLayer.rippleAt(point.x, point.y);
               }
    onClicked: {
      CompositorService.switchToWorkspace(workspace);
    }
  }

  Keys.onReturnPressed: event => {
                          CompositorService.switchToWorkspace(workspace);
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         CompositorService.switchToWorkspace(workspace);
                         event.accepted = true;
                       }

  // Burst effect overlay for focused pill
  Rectangle {
    id: pillBurst
    anchors.centerIn: pill
    width: pillContainer.pillWidth + 18 * masterProgress * scale
    height: pillContainer.pillHeight + 18 * masterProgress * scale
    radius: Style.radiusCapsule
    color: "transparent"
    border.color: effectColor
    border.width: Math.max(1, Math.round((2 + 6 * (1.0 - masterProgress))))
    opacity: effectsActive && workspace.isFocused ? (1.0 - masterProgress) * 0.7 : 0
    visible: effectsActive && workspace.isFocused
    z: 1
  }
}
