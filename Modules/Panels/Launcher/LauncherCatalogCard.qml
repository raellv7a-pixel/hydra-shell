import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

AbstractButton {
  id: root

  required property var launcher
  required property var entry
  required property int entryIndex
  property bool connectedToPanel: false

  readonly property bool contextTarget: launcher.appPanelItem === entry
  readonly property bool keyboardCurrent: launcher.ignoreMouseHover && launcher.selectedIndex === entryIndex
  readonly property bool selected: contextTarget || (!launcher.appPanelOpen && keyboardCurrent)
  readonly property var badgeState: entry.provider && entry.provider.packageStateForItem ? entry.provider.packageStateForItem(entry) : entry
  readonly property color foreground: selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurface

  hoverEnabled: !Settings.data.appLauncher.ignoreMouseInput
  focusPolicy: Qt.StrongFocus
  leftPadding: Style.marginL
  rightPadding: Style.marginL
  topPadding: Style.marginM
  bottomPadding: Style.marginM
  Accessible.role: Accessible.ListItem
  Accessible.name: entry.name || ""
  Accessible.description: entry.description || ""
  Accessible.selected: selected
  onVisualFocusChanged: if (visualFocus) {
    launcher.selectedIndex = entryIndex;
    launcher.ignoreMouseHover = true;
  }
  NDropShadow {
    z: -2
    anchors.fill: root.background
    source: root.background
    visible: root.visible && (root.selected || root.visualFocus || (root.hovered && !root.launcher.ignoreMouseHover && !root.launcher.appPanelOpen))
    autoPaddingEnabled: true
    shadowColor: HydraColor.mShadow
    shadowOpacity: Style.shadowOpacity * Style.opacityLight
    shadowHorizontalOffset: 0
    shadowVerticalOffset: Style.marginXXS
  }

  background: NBox {
    radius: Style.radiusM
    forceOpaque: true
    bottomLeftRadius: root.connectedToPanel ? Style.radiusXXS : Style.radiusM
    bottomRightRadius: root.connectedToPanel ? Style.radiusXXS : Style.radiusM
    color: Style.materialFill(Style.interactionColor(root.selected ? HydraColor.mPrimaryContainer : root.hovered && !root.launcher.ignoreMouseHover && !root.launcher.appPanelOpen ? HydraColor.mSurfaceContainerHighest : HydraColor.mSurfaceContainerHigh, root.foreground, root.hovered && !root.launcher.ignoreMouseHover && !root.launcher.appPanelOpen, root.down))
    border.width: root.keyboardCurrent || root.visualFocus ? Style.borderM : 0
    border.color: Style.focusOutlineColor(root.selected ? HydraColor.mPrimaryContainer : HydraColor.mSurfaceContainerHigh, root.foreground, HydraColor.mPrimary)

    Behavior on color {
      enabled: root.visible && !HydraColor.isTransitioning
      ColorAnimation {
        duration: root.down ? Style.hoverLeaveDuration : root.hovered ? Style.hoverEnterDuration : Style.hoverLeaveDuration
        easing.type: Easing.OutCubic
      }
    }
  }

  contentItem: RowLayout {
    spacing: Style.marginM

    LauncherAppIcon {
      Layout.preferredWidth: Math.round(36 * Style.uiScaleRatio)
      Layout.preferredHeight: Layout.preferredWidth
      Layout.minimumWidth: Layout.preferredWidth
      Layout.maximumWidth: Layout.preferredWidth
      appIcon: root.entry.icon || ""

      NBox {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Style.marginXL
        height: width
        radius: Style.radiusXXS
        color: HydraColor.mSurfaceContainerHighest
        visible: !!root.badgeState.badgeIcon
        NIcon {
          anchors.centerIn: parent
          icon: root.badgeState.badgeIcon || ""
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS
      NText {
        Layout.fillWidth: true
        text: root.entry.name || ""
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightSemiBold
        color: root.foreground
        elide: Text.ElideRight
        maximumLineCount: 1
      }
      NText {
        Layout.fillWidth: true
        text: root.entry.description || ""
        pointSize: Style.fontSizeS
        color: root.selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurfaceVariant
        elide: Text.ElideRight
        maximumLineCount: 1
        visible: text !== ""
      }
    }

    NIcon {
      Layout.minimumWidth: implicitWidth
      icon: root.contextTarget ? "chevron-down" : "chevron-right"
      pointSize: Style.fontSizeS
      color: root.selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurfaceVariant
      Accessible.ignored: true
    }
  }

  ToolTip.visible: hovered && !!badgeState.badgeTooltip
  ToolTip.text: badgeState.badgeTooltip || ""
  ToolTip.delay: 700
  onClicked: {
    launcher.selectedIndex = entryIndex;
    launcher.activateEntry(entry);
  }

  MouseArea {
    anchors.fill: parent
    enabled: Settings.data.appLauncher.ignoreMouseInput
    acceptedButtons: Qt.AllButtons
  }
  Keys.onPressed: event => launcher.handleKeyPress(event)

  TapHandler {
    acceptedButtons: Qt.RightButton
    enabled: !Settings.data.appLauncher.ignoreMouseInput
    onTapped: {
      root.launcher.selectedIndex = root.entryIndex;
      if (root.contextTarget)
        root.launcher.closeAppPanel();
      else
        root.launcher.openAppPanel(root.entry);
    }
  }

  Component.onCompleted: {
    if (entry.provider && entry.provider.prepareItem)
      entry.provider.prepareItem(entry);
  }
}
