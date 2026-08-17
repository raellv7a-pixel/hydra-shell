import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
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

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? ({})
  readonly property string screenName: screen?.name ?? ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      const widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length)
        return widgets[sectionWidgetIndex];
    }
    return ({});
  }

  readonly property bool hideWhenInactive: widgetSettings.hideWhenInactive ?? widgetMetadata.hideWhenInactive ?? false
  readonly property bool showElapsed: widgetSettings.showElapsed ?? widgetMetadata.showElapsed ?? true
  readonly property string iconColorKey: widgetSettings.iconColor ?? widgetMetadata.iconColor ?? "none"
  readonly property bool isVertical: ["left", "right"].includes(Settings.getBarPositionForScreen(screenName))
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property bool errorState: ObsControlService.effectiveState === "dependency-missing" || ObsControlService.effectiveState === "configuration-missing" || ObsControlService.effectiveState === "connection-error"
  readonly property bool shouldShow: !hideWhenInactive || ObsControlService.anyOutputActive || !ObsControlService.connected
  readonly property string outputText: {
    let labels = [];
    if (ObsControlService.recording)
      labels.push(I18n.tr("bar.obs-control.recording-short"));
    if (ObsControlService.streaming)
      labels.push(I18n.tr("bar.obs-control.streaming-short"));
    if (ObsControlService.replayBuffer)
      labels.push(I18n.tr("bar.obs-control.replay-short"));
    if (labels.length === 0)
      return "";
    let duration = 0;
    if (ObsControlService.recording)
      duration = ObsControlService.displayRecordDurationMs;
    else if (ObsControlService.streaming)
      duration = ObsControlService.displayStreamDurationMs;
    return showElapsed && duration > 0 ? `${labels.join("+")} ${formatDuration(duration)}` : labels.join("+");
  }
  readonly property color accentColor: errorState ? Color.mError : ObsControlService.recording ? Color.mError : ObsControlService.streaming ? Color.mPrimary : ObsControlService.replayBuffer ? Color.mSecondary : Color.resolveColorKey(iconColorKey)
  readonly property string iconName: ObsControlService.recording ? "player-record-filled" : ObsControlService.streaming ? "broadcast" : ObsControlService.replayBuffer ? "history" : errorState ? "alert-triangle" : ObsControlService.connected ? "brand-obs" : "plug-connected-x"
  readonly property string tooltipText: {
    let text = I18n.tr(`bar.obs-control.state-${ObsControlService.effectiveState}`);
    if (ObsControlService.anyOutputActive)
      text += `\n${I18n.tr("bar.obs-control.active-outputs")}: ${outputText}`;
    if (ObsControlService.lastError !== "" && ObsControlService.effectiveState === "connection-error")
      text += `\n${ObsControlService.lastError}`;
    return text;
  }

  visible: shouldShow
  implicitWidth: shouldShow ? (isVertical ? capsuleHeight : content.implicitWidth + Style.margin2M) : 0
  implicitHeight: shouldShow ? (isVertical ? content.implicitHeight + Style.margin2M : capsuleHeight) : 0

  function formatDuration(milliseconds) {
    const seconds = Math.floor(Math.max(0, milliseconds) / 1000);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainder = seconds % 60;
    const minuteText = String(minutes).padStart(2, "0");
    const secondText = String(remainder).padStart(2, "0");
    return hours > 0 ? `${hours}:${minuteText}:${secondText}` : `${minuteText}:${secondText}`;
  }

  Rectangle {
    anchors.fill: parent
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
  }

  Item {
    id: content
    anchors.centerIn: parent
    implicitWidth: root.isVertical ? verticalContent.implicitWidth : horizontalContent.implicitWidth
    implicitHeight: root.isVertical ? verticalContent.implicitHeight : horizontalContent.implicitHeight

    RowLayout {
      id: horizontalContent
      anchors.centerIn: parent
      visible: !root.isVertical
      spacing: Style.marginS

      NIcon {
        icon: root.iconName
        color: root.accentColor
        pointSize: Math.round(root.barFontSize * 1.1)
        applyUiScale: false
      }
      NText {
        visible: root.outputText !== ""
        text: root.outputText
        color: root.accentColor
        pointSize: root.barFontSize
        applyUiScale: false
        font.weight: Style.fontWeightSemiBold
      }
    }

    ColumnLayout {
      id: verticalContent
      anchors.centerIn: parent
      visible: root.isVertical
      spacing: Style.marginXXS

      NIcon {
        Layout.alignment: Qt.AlignHCenter
        icon: root.iconName
        color: root.accentColor
        pointSize: root.barFontSize
        applyUiScale: false
      }
      NText {
        Layout.alignment: Qt.AlignHCenter
        visible: root.outputText !== ""
        text: root.outputText
        color: root.accentColor
        pointSize: root.barFontSize * 0.8
        applyUiScale: false
        font.weight: Style.fontWeightSemiBold
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
    onExited: TooltipService.hide(root)
    onPressed: TooltipService.hide(root)
    onClicked: mouse => {
                 if (mouse.button === Qt.LeftButton) {
                   PanelService.getPanel("obsControlPanel", root.screen)?.toggle(root);
                 } else if (mouse.button === Qt.MiddleButton) {
                   ObsControlService.toggleRecord();
                 } else if (mouse.button === Qt.RightButton) {
                   PanelService.showContextMenu(contextMenu, root, root.screen);
                 }
               }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        label: I18n.tr("bar.obs-control.refresh"),
        action: "refresh",
        icon: "refresh"
      },
      {
        label: I18n.tr("actions.widget-settings"),
        action: "settings",
        icon: "settings"
      }
    ]
    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(root.screen);
                   if (action === "refresh")
                   ObsControlService.refresh();
                   else if (action === "settings")
                   BarService.openWidgetSettings(root.screen, root.section, root.sectionWidgetIndex, root.widgetId, root.widgetSettings);
                 }
  }
}
