import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // Sizing - modern attached panel matching reference design
  preferredWidth: Math.round(380 * Style.uiScaleRatio)
  preferredHeight: Math.round(580 * Style.uiScaleRatio)
  preferredWidthRatio: 0
  preferredHeightRatio: 0

  blurEnabled: true
  panelBackgroundColor: Color.mSurface

  // Attachment to bar & screen positioning
  readonly property string screenBarPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isFramed: Settings.data.bar.barType === "framed"
  readonly property string panelPosition: {
    var pos = Settings.data.sessionMenu.position;
    if (pos === "follow_bar") {
      if (screenBarPosition === "left" || screenBarPosition === "right") {
        return `center_${screenBarPosition}`;
      } else {
        return `${screenBarPosition}_center`;
      }
    }
    return pos;
  }

  panelAnchorHorizontalCenter: !isFramed && (panelPosition === "center" || panelPosition.endsWith("_center"))
  panelAnchorVerticalCenter: isFramed || panelPosition === "center" || panelPosition.startsWith("center_")
  panelAnchorLeft: !isFramed && panelPosition !== "center" && panelPosition.endsWith("_left")
  panelAnchorRight: isFramed || (panelPosition !== "center" && panelPosition.endsWith("_right"))
  panelAnchorBottom: !isFramed && panelPosition.startsWith("bottom_")
  panelAnchorTop: !isFramed && panelPosition.startsWith("top_")

  // SessionMenu handles its own closing logic
  property bool closeWithEscape: false

  // Timer properties
  readonly property int timerDuration: Settings.data.sessionMenu.countdownDuration
  property string pendingAction: ""
  property bool timerActive: false
  property int timeRemaining: 0

  // Uptime state
  property string uptimeText: "--"

  Timer {
    interval: 30000
    repeat: true
    running: root.isPanelOpen
    onTriggered: uptimeProcess.running = true
  }

  Process {
    id: uptimeProcess
    command: ["cat", "/proc/uptime"]
    running: root.isPanelOpen

    stdout: StdioCollector {
      onStreamFinished: {
        var uptimeSeconds = parseFloat(this.text.trim().split(' ')[0]);
        root.uptimeText = Time.formatVagueHumanReadableDuration(uptimeSeconds);
        uptimeProcess.running = false;
      }
    }
  }

  // Navigation properties
  property int selectedIndex: -1
  property bool ignoreMouseHover: true

  property real globalLastMouseX: 0
  property real globalLastMouseY: 0
  property bool globalMouseInitialized: false
  property bool mouseTrackingReady: false

  Timer {
    id: mouseTrackingDelayTimer
    interval: Style.animationNormal + 50
    repeat: false
    onTriggered: {
      root.mouseTrackingReady = true;
      root.globalMouseInitialized = false;
    }
  }

  // Profile wallpaper path for left card background
  readonly property string profileWallpaperPath: {
    var mode = Settings.data.sessionMenu.coverCardMode || "auto";
    if (mode === "custom" && Settings.data.sessionMenu.coverCardPath) {
      return Settings.preprocessPath(Settings.data.sessionMenu.coverCardPath);
    }
    if (mode === "avatar" && Settings.data.general.avatarImage) {
      return Settings.preprocessPath(Settings.data.general.avatarImage);
    }
    var wp = WallpaperService.getWallpaper(screen?.name ?? "");
    if (wp && !WallpaperService.isSolidColorPath(wp)) return wp;
    return WallpaperService.defaultWallpaper || "";
  }

  // Action metadata mapping
  readonly property var actionMetadata: {
    "lock": {
      "icon": "lock",
      "title": I18n.tr("common.lock"),
      "isShutdown": false
    },
    "suspend": {
      "icon": "suspend",
      "title": I18n.tr("common.suspend"),
      "isShutdown": false
    },
    "hibernate": {
      "icon": "leaf",
      "title": I18n.tr("common.hibernate"),
      "isShutdown": false
    },
    "reboot": {
      "icon": "reboot",
      "title": I18n.tr("common.reboot"),
      "isShutdown": false
    },
    "userspaceReboot": {
      "icon": "rotate",
      "title": I18n.tr("common.userspace-reboot"),
      "isShutdown": false
    },
    "rebootToUefi": {
      "icon": "reboot",
      "title": I18n.tr("common.reboot-to-uefi"),
      "isShutdown": false
    },
    "logout": {
      "icon": "logout",
      "title": I18n.tr("common.logout"),
      "isShutdown": false
    },
    "shutdown": {
      "icon": "shutdown",
      "title": I18n.tr("common.shutdown"),
      "isShutdown": true
    }
  }

  // Build powerOptions from settings
  property int _powerOptionsVersion: 0
  property var powerOptions: {
    void (_powerOptionsVersion);
    var options = [];
    var settingsOptions = Settings.data.sessionMenu.powerOptions || [];

    for (var i = 0; i < settingsOptions.length; i++) {
      var settingOption = settingsOptions[i];
      if (settingOption.enabled && actionMetadata[settingOption.action]) {
        var metadata = actionMetadata[settingOption.action];
        options.push({
          "action": settingOption.action,
          "icon": metadata.icon,
          "title": metadata.title,
          "isShutdown": metadata.isShutdown,
          "countdownEnabled": settingOption.countdownEnabled !== undefined ? settingOption.countdownEnabled : true,
          "command": settingOption.command || "",
          "keybind": settingOption.keybind || ""
        });
      }
    }
    return options;
  }

  Connections {
    target: Settings.data.sessionMenu
    function onPowerOptionsChanged() {
      root._powerOptionsVersion++;
    }
  }

  // Lifecycle handlers
  onOpened: {
    if (powerOptions.length > 0) {
      selectedIndex = -1;
      ignoreMouseHover = true;
      globalMouseInitialized = false;
      mouseTrackingReady = false;
      mouseTrackingDelayTimer.restart();
      uptimeProcess.running = true;
    } else {
      Logger.w("SessionMenu", "Trying to open an empty session menu");
      root.closeImmediately();
    }
  }

  onClosed: {
    cancelTimer();
    selectedIndex = -1;
    ignoreMouseHover = true;
  }

  // Timer management
  function startTimer(action) {
    if (!Settings.data.sessionMenu.enableCountdown) {
      executeAction(action);
      return;
    }

    var option = null;
    for (var i = 0; i < powerOptions.length; i++) {
      if (powerOptions[i].action === action) {
        option = powerOptions[i];
        break;
      }
    }

    if (option && option.countdownEnabled === false) {
      executeAction(action);
      return;
    }

    if (timerActive && pendingAction === action) {
      executeAction(action);
      return;
    }

    pendingAction = action;
    timeRemaining = timerDuration;
    timerActive = true;
    countdownTimer.start();
  }

  function cancelTimer() {
    timerActive = false;
    pendingAction = "";
    timeRemaining = 0;
    countdownTimer.stop();
  }

  function executeAction(action) {
    countdownTimer.stop();

    switch (action) {
    case "lock":
      CompositorService.lock();
      break;
    case "suspend":
      if (Settings.data.general.lockOnSuspend) {
        CompositorService.lockAndSuspend();
      } else {
        CompositorService.suspend();
      }
      break;
    case "hibernate":
      CompositorService.hibernate();
      break;
    case "reboot":
      CompositorService.reboot();
      break;
    case "userspaceReboot":
      CompositorService.userspaceReboot();
      break;
    case "rebootToUefi":
      CompositorService.rebootToUefi();
      break;
    case "logout":
      CompositorService.logout();
      break;
    case "shutdown":
      CompositorService.shutdown();
      break;
    }

    cancelTimer();
    root.close();
  }

  // Navigation functions for 2x4 grid (or less)
  function getGridInfo() {
    let columns = 2;
    let rows = Math.ceil(powerOptions.length / columns);
    return {
      columns,
      rows,
      currentRow: selectedIndex >= 0 ? Math.floor(selectedIndex / columns) : -1,
      currentCol: selectedIndex >= 0 ? selectedIndex % columns : -1,
      itemsInRow: row => Math.min(columns, powerOptions.length - row * columns)
    };
  }

  function navigateGrid(direction) {
    if (powerOptions.length === 0) return;

    const grid = getGridInfo();
    let newRow = grid.currentRow >= 0 ? grid.currentRow : 0;
    let newCol = grid.currentCol >= 0 ? grid.currentCol : 0;

    switch (direction) {
    case "left":
      newCol = newCol - 1 < 0 ? grid.itemsInRow(newRow) - 1 : newCol - 1;
      break;
    case "right":
      newCol = grid.currentCol < 0 ? 0 : (newCol + 1 >= grid.itemsInRow(newRow) ? 0 : newCol + 1);
      break;
    case "up":
      newRow = newRow - 1 < 0 ? grid.rows - 1 : newRow - 1;
      break;
    case "down":
      newRow = grid.currentRow < 0 ? 0 : (newRow + 1 >= grid.rows ? 0 : newRow + 1);
      break;
    }

    const itemsInNewRow = grid.itemsInRow(newRow);
    newCol = Math.min(newCol, itemsInNewRow - 1);

    const newIndex = newRow * grid.columns + newCol;
    if (newIndex < powerOptions.length) {
      selectedIndex = newIndex;
    }
  }

  function selectNextWrapped() {
    if (powerOptions.length > 0) {
      selectedIndex = selectedIndex < 0 ? 0 : (selectedIndex + 1) % powerOptions.length;
    }
  }

  function selectPreviousWrapped() {
    if (powerOptions.length > 0) {
      selectedIndex = selectedIndex < 0 ? powerOptions.length - 1 : (((selectedIndex - 1) % powerOptions.length) + powerOptions.length) % powerOptions.length;
    }
  }

  function selectFirst() {
    if (powerOptions.length > 0) selectedIndex = 0;
  }

  function selectLast() {
    if (powerOptions.length > 0) selectedIndex = powerOptions.length - 1;
  }

  function activate() {
    if (powerOptions.length > 0 && selectedIndex >= 0 && powerOptions[selectedIndex]) {
      startTimer(powerOptions[selectedIndex].action);
    }
  }

  function checkKey(event, settingName) {
    return Keybinds.checkKey(event, settingName, Settings);
  }

  function handleUp() { navigateGrid("up"); }
  function handleDown() { navigateGrid("down"); }
  function handleLeft() { navigateGrid("left"); }
  function handleRight() { navigateGrid("right"); }
  function handleEnter() { activate(); }

  function handleEscape() {
    if (timerActive) {
      cancelTimer();
    } else {
      root.close();
    }
  }

  function onEscapePressed() { handleEscape(); }
  function onTabPressed() { selectNextWrapped(); }
  function onBackTabPressed() { selectPreviousWrapped(); }
  function onLeftPressed() { handleLeft(); }
  function onRightPressed() { handleRight(); }
  function onUpPressed() { handleUp(); }
  function onDownPressed() { handleDown(); }
  function onEnterPressed() { handleEnter(); }
  function onHomePressed() { selectFirst(); }
  function onEndPressed() { selectLast(); }

  function checkKeybind(event) {
    if (powerOptions.length === 0) return false;
    if (event.key === Qt.Key_Control || event.key === Qt.Key_Shift || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
      return false;
    }
    const pressedKeybind = Keybinds.getKeybindString(event);
    if (!pressedKeybind) return false;

    for (var i = 0; i < powerOptions.length; i++) {
      if (powerOptions[i].keybind === pressedKeybind) {
        selectedIndex = i;
        startTimer(powerOptions[i].action);
        return true;
      }
    }
    return false;
  }

  // Countdown timer
  Timer {
    id: countdownTimer
    interval: 100
    repeat: true
    onTriggered: {
      timeRemaining -= interval;
      if (timeRemaining <= 0) {
        executeAction(pendingAction);
      }
    }
  }

  panelContent: Rectangle {
    id: panelContent
    color: "transparent"
    focus: true

    Connections {
      target: root
      function onOpened() {
        Qt.callLater(() => {
          panelContent.forceActiveFocus();
        });
      }
    }

    Keys.onPressed: event => {
      if (root.checkKeybind(event)) { event.accepted = true; return; }
      if (checkKey(event, 'up')) { handleUp(); event.accepted = true; return; }
      if (checkKey(event, 'down')) { handleDown(); event.accepted = true; return; }
      if (checkKey(event, 'left')) { handleLeft(); event.accepted = true; return; }
      if (checkKey(event, 'right')) { handleRight(); event.accepted = true; return; }
      if (checkKey(event, 'enter')) { handleEnter(); event.accepted = true; return; }
      if (checkKey(event, 'escape')) { handleEscape(); event.accepted = true; return; }
      if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
        event.accepted = true;
        return;
      }
    }

    HoverHandler {
      id: globalHoverHandler
      onPointChanged: {
        if (!root.mouseTrackingReady) return;
        if (!root.globalMouseInitialized) {
          root.globalLastMouseX = point.position.x;
          root.globalLastMouseY = point.position.y;
          root.globalMouseInitialized = true;
          return;
        }
        const deltaX = Math.abs(point.position.x - root.globalLastMouseX);
        const deltaY = Math.abs(point.position.y - root.globalLastMouseY);
        if (deltaX + deltaY >= 5) {
          root.ignoreMouseHover = false;
          root.globalLastMouseX = point.position.x;
          root.globalLastMouseY = point.position.y;
        }
      }
    }

    NBox {
      anchors.fill: parent
      anchors.margins: Style.marginM
      color: Color.mSurfaceVariant
      radius: Style.radiusL

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // TOP CARD - Cover Wallpaper + Profile Badge + Uptime
        Item {
          id: topCard
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(280 * Style.uiScaleRatio)

          NImageRounded {
            id: leftCardImage
            anchors.fill: parent
            imagePath: root.profileWallpaperPath
            imageFillMode: Image.PreserveAspectCrop
            radius: Style.radiusM
          }

          Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.25
            radius: Style.radiusM
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            // User Profile Badge Box (Top)
            Rectangle {
              visible: Settings.data.sessionMenu.showProfileBadge ?? true
              Layout.fillWidth: true
              Layout.preferredHeight: Math.round(42 * Style.uiScaleRatio)
              radius: Style.radiusM
              color: Qt.rgba(1, 1, 1, 0.18)
              border.color: Qt.rgba(1, 1, 1, 0.3)
              border.width: Style.borderS

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.marginS

                NIcon {
                  icon: "person"
                  pointSize: Style.fontSizeM
                  color: "white"
                }

                NText {
                  text: HostService.displayName || Quickshell.env("USER") || "user"
                  font.weight: Style.fontWeightBold
                  pointSize: Style.fontSizeM
                  color: "white"
                  elide: Text.ElideRight
                }
              }
            }

            Item { Layout.fillHeight: true }

            // Uptime Box (Bottom)
            Rectangle {
              visible: Settings.data.sessionMenu.showUptimeBadge ?? true
              Layout.fillWidth: true
              Layout.preferredHeight: Math.round(36 * Style.uiScaleRatio)
              radius: Style.radiusM
              color: Qt.rgba(0, 0, 0, 0.5)
              border.color: Qt.rgba(255, 255, 255, 0.15)
              border.width: Style.borderS

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.marginS

                NIcon {
                  icon: "clock"
                  pointSize: Style.fontSizeS
                  color: "white"
                }

                NText {
                  text: I18n.tr("system.uptime", { "uptime": root.uptimeText })
                  pointSize: Style.fontSizeS
                  color: "white"
                  font.weight: Style.fontWeightMedium
                }
              }
            }
          }
        }

        // BOTTOM SIDE - Grid of Power Action Buttons
        GridLayout {
          id: powerGrid
          Layout.fillWidth: true
          Layout.fillHeight: true
          columns: 2
          rowSpacing: Style.marginS
          columnSpacing: Style.marginS

          Repeater {
            model: powerOptions
            delegate: ModernPowerButton {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.columnSpan: (index === powerOptions.length - 1 && powerOptions.length % 2 !== 0) ? 2 : 1
              icon: modelData.icon
              title: modelData.title
              isShutdown: modelData.isShutdown || false
              isSelected: index === selectedIndex
              number: index + 1
              buttonIndex: index
              onClicked: {
                selectedIndex = index;
                startTimer(modelData.action);
              }
              pending: timerActive && pendingAction === modelData.action
              keybind: modelData.keybind || ""
            }
          }
        }
      }
    }
  }

  // Modern Power Button Component for 2x3 Grid
  component ModernPowerButton: Rectangle {
    id: buttonRoot

    property string icon: ""
    property string title: ""
    property bool pending: false
    property bool isShutdown: false
    property bool isSelected: false
    property int number: 0
    property string keybind: ""
    property int buttonIndex: -1

    readonly property bool effectiveHover: !root.ignoreMouseHover && mouseArea.containsMouse
    readonly property bool activeFocusOrHover: isSelected || effectiveHover

    signal clicked

    radius: Style.radiusM
    color: {
      if (pending) return Color.mPrimary;
      if (activeFocusOrHover) return Color.mPrimary;
      return Color.mSurface;
    }

    border.width: Style.borderS
    border.color: activeFocusOrHover ? Color.mOnPrimary : Color.mOutline

    scale: activeFocusOrHover ? 1.05 : 1.0

    Behavior on scale {
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
      }
    }

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCirc
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginXXS

      NIcon {
        id: iconElem
        Layout.alignment: Qt.AlignHCenter
        icon: buttonRoot.icon
        pointSize: Style.fontSizeXXXL * 1.1
        color: {
          if (buttonRoot.pending || buttonRoot.activeFocusOrHover) return Color.mOnPrimary;
          if (buttonRoot.isShutdown) return Color.mError;
          return Color.mOnSurface;
        }
        scale: buttonRoot.activeFocusOrHover ? 1.15 : 1.0

        Behavior on scale {
          NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
          }
        }
        Behavior on color {
          ColorAnimation { duration: Style.animationFast }
        }
      }

      NText {
        Layout.alignment: Qt.AlignHCenter
        text: buttonRoot.pending ? (Math.ceil(timeRemaining / 1000) + "s") : buttonRoot.title
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightMedium
        color: (buttonRoot.pending || buttonRoot.activeFocusOrHover) ? Color.mOnPrimary : Color.mOnSurfaceVariant
        elide: Text.ElideRight
        maximumLineCount: 1

        Behavior on color {
          ColorAnimation { duration: Style.animationFast }
        }
      }
    }

    // Keybind indicator in top-right corner if present
    Rectangle {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: Style.marginXS
      width: keybindText.implicitWidth + Style.marginS
      height: keybindText.implicitHeight + 2
      radius: Style.radiusXS
      color: buttonRoot.activeFocusOrHover ? Color.mOnPrimary : Color.mSurfaceVariant
      visible: Settings.data.sessionMenu.showKeybinds && (buttonRoot.keybind !== "") && !buttonRoot.pending
      z: 5

      NText {
        id: keybindText
        anchors.centerIn: parent
        text: buttonRoot.keybind
        pointSize: Style.fontSizeXXS
        color: buttonRoot.activeFocusOrHover ? Color.mPrimary : Color.mOnSurfaceVariant
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onEntered: {
        if (!root.ignoreMouseHover) {
          selectedIndex = buttonRoot.buttonIndex;
        }
      }
      onExited: {
        if (!root.ignoreMouseHover && selectedIndex === buttonRoot.buttonIndex) {
          selectedIndex = -1;
        }
      }
      onClicked: buttonRoot.clicked()
    }
  }
}
