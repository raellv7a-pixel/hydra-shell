pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

/**
* EdgeShelf - Per-screen edge launcher and scratchpad surface
*
* Implements framed left-strip handle reveal on hover, click/drag open,
* Material 3 surface emerging contiguously from the frame, central icons,
* window running/scratchpad state indicators, bounded scrollable pinned app
* list with fixed Launcher plus button, and anchored scrollable window chooser.
*/
Item {
  id: root

  // --------------------------------------------------------------------------
  // Public Contract Properties (wired by MainScreen)
  // --------------------------------------------------------------------------
  property ShellScreen screen: null
  property bool available: (Settings.data.edgeShelf?.enabled ?? false) && (Settings.data.bar.barType === "framed") && CompositorService.isUmbriel
  property real frameLeft: {
    const isLeftBar = Settings.getBarPositionForScreen(screen?.name) === "left";
    return isLeftBar ? Style.getBarHeightForScreen(screen?.name) : (Settings.data.bar.frameThickness ?? 12);
  }
  property bool opened: false

  // Keyboard navigation
  focus: opened

  // --------------------------------------------------------------------------
  // Keep the rail flush against the Frame's inner left edge.
  readonly property real surfaceX: frameLeft

  // --------------------------------------------------------------------------
  // Public Contract Methods & Signals
  // --------------------------------------------------------------------------
  function openShelf() {
    if (!root.available)
      return;
    root.opened = true;
    root.forceActiveFocus();
  }

  function closeShelf() {
    root.opened = false;
    resetChooser();
  }

  Connections {
    target: CompositorService
    function onOverviewActiveChanged() {
      if (CompositorService.overviewActive) root.closeShelf();
    }
  }

  signal requestLauncher

  // --------------------------------------------------------------------------
  // Theming & Material 3 Colors
  // --------------------------------------------------------------------------
  readonly property real frameOpacity: Settings.data.bar.useSeparateOpacity ? Style.effectiveBarOpacity : Style.effectivePanelOpacity

  // Translucent primary for Material 3 state layers (avoids saturated Color.mHover)
  readonly property color hoverColor: Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.12)
  readonly property color hoverColorStrong: Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.20)
  readonly property color associatedBg: Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.22)

  // --------------------------------------------------------------------------
  // Internal Sizing and Geometry
  // --------------------------------------------------------------------------
  readonly property real railWidth: 64
  readonly property real chooserWidth: Math.min(260, Math.max(180, width - frameLeft - railWidth - 24))
  readonly property real chooserOverlap: 1

  readonly property real topHoleY: {
    const isTopBar = Settings.getBarPositionForScreen(screen?.name) === "top";
    return isTopBar ? Style.getBarHeightForScreen(screen?.name) : (Settings.data.bar.frameThickness ?? 12);
  }
  readonly property real bottomHoleY: {
    const isBottomBar = Settings.getBarPositionForScreen(screen?.name) === "bottom";
    const bottomThick = isBottomBar ? Style.getBarHeightForScreen(screen?.name) : (Settings.data.bar.frameThickness ?? 12);
    return (screen?.height ?? 1080) - bottomThick;
  }
  readonly property real maxAvailableHeight: Math.max(160, bottomHoleY - topHoleY - 32)

  readonly property var pinnedApps: Settings.data.edgeShelf?.pinnedApps ?? []
  readonly property real itemSize: 48
  readonly property real itemSpacing: 8
  readonly property real listPadding: 8

  // Fixed bottom section height (separator + plus button)
  readonly property real bottomSectionHeight: (pinnedApps.length > 0 ? 13 : 0) + itemSize
  // Unbounded natural content height of pinned apps list
  readonly property real naturalAppsHeight: pinnedApps.length > 0 ? (pinnedApps.length * (itemSize + itemSpacing) - itemSpacing) : 0
  readonly property real naturalTotalHeight: naturalAppsHeight + bottomSectionHeight + (listPadding * 2)

  readonly property real shelfHeight: Math.min(maxAvailableHeight, Math.max(120, naturalTotalHeight))
  readonly property real frameCenterY: topHoleY + (bottomHoleY - topHoleY) / 2
  readonly property real shelfY: Math.max(topHoleY + 16, Math.min(bottomHoleY - 16 - shelfHeight, frameCenterY - shelfHeight / 2))

  // --------------------------------------------------------------------------
  // Surface Reveal Animation (growing from frame on open)
  // --------------------------------------------------------------------------
  property real revealProgress: opened ? 1.0 : 0.0
  Behavior on revealProgress {
    NumberAnimation {
      duration: Settings.data.general.animationDisabled ? 0 : Style.animationFast
      easing.type: root.opened ? Easing.OutCubic : Easing.InCubic
    }
  }
  readonly property real revealWidth: railWidth * revealProgress

  // The Frame consumes this geometry in its own inner-hole ShapePath.
  property real handleProgress: available && (opened || handleMouseArea.containsMouse || handleMouseArea.pressed) ? (handleMouseArea.pressed ? 0.85 : 1.0) : 0.0
  Behavior on handleProgress {
    NumberAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }
  readonly property real handleDepth: Style.radiusM * handleProgress
  readonly property real handleHeight: Math.min(shelfHeight, Style.baseWidgetSize * 3)
  readonly property real handleHitWidth: frameLeft + handleDepth * (1 - revealProgress)
  readonly property real frameBulgeDepth: available ? handleDepth * (1 - revealProgress) + revealWidth : 0
  readonly property real frameBulgeHalfHeight: handleHeight / 2 * (1 - revealProgress) + (shelfHeight / 2 + Style.radiusL) * revealProgress
  readonly property real frameBulgeShoulder: handleHeight * 0.425 * (1 - revealProgress) + Style.radiusL * 2 * revealProgress

  // --------------------------------------------------------------------------
  // Reactivity to Compositor & Windows
  // --------------------------------------------------------------------------
  readonly property int _winRev: (typeof EdgeShelfService !== "undefined" && EdgeShelfService && EdgeShelfService.windowRevision !== undefined) ? EdgeShelfService.windowRevision : 0

  onOpenedChanged: {
    if (opened) {
      root.forceActiveFocus();
    } else {
      resetChooser();
    }
  }

  onAvailableChanged: {
    if (!available && opened) {
      closeShelf();
    }
  }

  Keys.onEscapePressed: event => {
    root.closeShelf();
    event.accepted = true;
  }

  // --------------------------------------------------------------------------
  // Chooser State
  // --------------------------------------------------------------------------
  property bool chooserVisible: false
  property string chooserAppId: ""
  property var chooserCandidates: []
  property real chooserAnchorTileY: 0
  property real chooserAnchorTileHeight: itemSize

  readonly property real maxCandidateListHeight: Math.max(68, maxAvailableHeight - 80)
  readonly property real candidateRowHeight: 34
  readonly property real candidateSpacing: 4
  readonly property real naturalCandidateListHeight: chooserCandidates.length > 0 ? (chooserCandidates.length * (candidateRowHeight + candidateSpacing) - candidateSpacing) : 0
  readonly property real effectiveCandidateListHeight: Math.min(maxCandidateListHeight, naturalCandidateListHeight)
  readonly property real chooserCalculatedHeight: Math.min(maxAvailableHeight, 52 + effectiveCandidateListHeight + 16)
  readonly property real chooserCalculatedY: {
    const targetY = chooserAnchorTileY + (chooserAnchorTileHeight - chooserCalculatedHeight) / 2;
    return Math.max(topHoleY + 8, Math.min(bottomHoleY - chooserCalculatedHeight - 8, targetY));
  }

  function resetChooser() {
    chooserVisible = false;
    chooserAppId = "";
    chooserCandidates = [];
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  function getAppName(appId) {
    if (!appId)
      return "";
    try {
      const entry = ThemeIcons.findAppEntry(appId);
      if (entry && entry.name)
        return entry.name;
    } catch (e) {}
    let clean = appId.replace(/\.desktop$/i, "");
    return clean.charAt(0).toUpperCase() + clean.slice(1);
  }

  function getAppIcon(appId) {
    if (!appId)
      return "";
    try {
      // Image.source needs a resolved path; a bare icon name is treated as a
      // relative file URL when a chooser is cleared during a transition.
      return ThemeIcons.iconForAppId(appId.toLowerCase(), "application-x-executable") || "";
    } catch (e) {
      return "";
    }
  }

  function handleAppClick(appId, delegateItem) {
    if (typeof EdgeShelfService === "undefined" || !EdgeShelfService)
      return;
    const candidates = EdgeShelfService.selectApp(appId, root.screen);
    if (candidates && candidates.length > 1) {
      chooserAppId = appId;
      chooserCandidates = candidates;
      const globalPos = delegateItem.mapToItem(root, 0, 0);
      chooserAnchorTileY = globalPos.y;
      chooserAnchorTileHeight = delegateItem.height;
      chooserVisible = true;
    } else {
      resetChooser();
    }
  }

  // --------------------------------------------------------------------------
  // 1. Local Frame interaction area; only the revealed deformation extends inward.
  // --------------------------------------------------------------------------
  Item {
    id: handleHitBox
    visible: root.available
    x: 0
    y: root.shelfY + (root.shelfHeight - height) / 2
    width: root.handleHitWidth
    height: root.handleHeight
    z: 10

    MouseArea {
      id: handleMouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      property real pressStartX: 0
      property real pressStartY: 0
      property bool isDragging: false

      onPressed: mouse => {
        pressStartX = mouse.x;
        pressStartY = mouse.y;
        isDragging = false;
      }

      onPositionChanged: mouse => {
        if (pressed) {
          const dx = mouse.x - pressStartX;
          if (dx > 12) { // Short rightward drag opens shelf
            if (!root.opened) {
              root.openShelf();
            }
            isDragging = true;
          }
        }
      }

      onClicked: mouse => {
        if (!isDragging) {
          if (root.opened) {
            root.closeShelf();
          } else {
            root.openShelf();
          }
        }
      }
    }

    // Only the glyph is drawn here; the material belongs to the Frame path.
    NIcon {
      id: handleGlyph
      icon: "chevron-right"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      opacity: root.handleProgress * (1 - root.revealProgress)
      visible: opacity > 0
      x: root.frameLeft + root.handleDepth / 2 - handleMetrics.tightBoundingRect.width / 2 - handleMetrics.tightBoundingRect.x
      y: (parent.height - handleMetrics.tightBoundingRect.height) / 2 - handleMetrics.tightBoundingRect.y
    }

    TextMetrics {
      id: handleMetrics
      font: handleGlyph.font
      text: handleGlyph.text
    }
  }

  // --------------------------------------------------------------------------
  // 2. Animated Shelf Surface (grows contiguously eastward from left frame)
  // --------------------------------------------------------------------------
  Item {
    id: shelfSurfaceContainer
    x: root.surfaceX
    y: root.shelfY
    width: root.revealWidth
    height: root.shelfHeight
    visible: root.available && (root.opened || root.revealProgress > 0)
    clip: true
    z: 5

    // Seam gradient along moving edge (panels emerging from underneath desktop)
    Rectangle {
      id: movingEdgeSeam
      x: shelfSurfaceContainer.width - width
      y: cornerInset
      width: Math.min(20, shelfSurfaceContainer.width)
      height: Math.max(0, shelfSurfaceContainer.height - cornerInset * 2)
      readonly property real cornerInset: Math.min(Style.radiusL, shelfSurfaceContainer.height / 2)
      color: "transparent"
      antialiasing: true
      opacity: Math.min(1.0, shelfSurfaceContainer.width / 20)
      visible: shelfSurfaceContainer.width > 2

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
          position: 0
          color: "transparent"
        }
        GradientStop {
          position: 0.5
          color: Qt.rgba(Color.mShadow.r, Color.mShadow.g, Color.mShadow.b, Color.mShadow.a * 0.10)
        }
        GradientStop {
          position: 1
          color: Qt.rgba(Color.mShadow.r, Color.mShadow.g, Color.mShadow.b, Color.mShadow.a * 0.34)
        }
      }
    }

    // Consume blank rail clicks; only clicks outside the surface dismiss it.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    }

    // Content container (fixed rail width to prevent content reflow during reveal)
    Item {
      width: root.railWidth
      height: root.shelfHeight
      opacity: root.revealProgress

      // Bounded scrollable pinned app list
      Flickable {
        id: appListFlickable
        anchors.top: parent.top
        anchors.topMargin: root.listPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.railWidth
        height: Math.max(0, root.shelfHeight - bottomSection.height - root.listPadding)
        contentWidth: width
        contentHeight: appColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: contentHeight > height

        Column {
          id: appColumn
          width: root.railWidth
          spacing: root.itemSpacing

          // Pinned Apps in user-configured order
          Repeater {
            model: root.pinnedApps

            delegate: Rectangle {
              id: appTile
              required property var modelData
              required property int index

              readonly property bool isRunning: {
                const rev = root._winRev;
                if (typeof EdgeShelfService !== "undefined" && EdgeShelfService && EdgeShelfService.isRunning) {
                  return EdgeShelfService.isRunning(modelData);
                }
                return false;
              }

              readonly property bool isAssociated: {
                const rev = root._winRev;
                if (typeof EdgeShelfService !== "undefined" && EdgeShelfService && EdgeShelfService.isAssociated) {
                  return EdgeShelfService.isAssociated(modelData);
                }
                return false;
              }

              width: root.itemSize
              height: root.itemSize
              anchors.horizontalCenter: parent.horizontalCenter
              radius: Style.radiusM

              color: {
                if (isAssociated) {
                  return tileMouseArea.containsMouse ? root.hoverColorStrong : root.associatedBg;
                }
                if (tileMouseArea.containsMouse) {
                  return root.hoverColor;
                }
                return "transparent";
              }
              border.color: isAssociated ? Color.mPrimary : "transparent"
              border.width: isAssociated ? Style.borderS : 0

              // Centered Application Icon
              Image {
                anchors.centerIn: parent
                width: 28
                height: 28
                source: root.getAppIcon(modelData)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
              }

              // Scratchpad Association Indicator (accent bar along inner frame side)
              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 18
                radius: 1.5
                color: Color.mPrimary
                visible: appTile.isAssociated
              }

              // Running Indicator Dot (when running in compositor but unassociated)
              Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 4
                radius: 2
                color: Color.mOnSurfaceVariant
                visible: appTile.isRunning && !appTile.isAssociated
              }

              // Interaction
              MouseArea {
                id: tileMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: TooltipService.show(parent, root.getAppName(modelData), "right")
                onExited: TooltipService.hide()
                onPressed: TooltipService.hide()
                onClicked: {
                  TooltipService.hide();
                  root.handleAppClick(modelData, appTile);
                }
              }
            }
          }
        }
      }

      // Fixed bottom section: Launcher Plus button always visible and accessible
      Item {
        id: bottomSection
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.listPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.railWidth
        height: root.bottomSectionHeight

        Column {
          anchors.fill: parent
          spacing: 6

          // Separator before Launcher plus
          Rectangle {
            width: 32
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Color.mOutline
            opacity: 0.5
            visible: root.pinnedApps.length > 0
          }

          // Plus Button: requests Launcher and closes shelf
          Rectangle {
            id: plusTile
            width: root.itemSize
            height: root.itemSize
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Style.radiusM
            color: plusMouseArea.containsMouse ? root.hoverColorStrong : root.hoverColor

            NIcon {
              anchors.centerIn: parent
              icon: "plus"
              pointSize: Style.fontSizeM
              color: Color.mOnSurfaceVariant
            }

            MouseArea {
              id: plusMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onEntered: TooltipService.show(parent, I18n.tr("common.add") ?? "Add", "right")
              onExited: TooltipService.hide()
              onPressed: TooltipService.hide()
              onClicked: {
                TooltipService.hide();
                root.requestLauncher();
                root.closeShelf();
              }
            }
          }
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // 3. Anchored Minimal Chooser (displayed beside tile on multiple candidate windows)
  // --------------------------------------------------------------------------
  Item {
    id: chooserContainer
    visible: root.opened && root.chooserVisible && root.chooserCandidates.length > 1
    x: root.surfaceX + root.railWidth - root.chooserOverlap
    y: root.chooserCalculatedY
    width: root.chooserWidth
    height: root.chooserCalculatedHeight
    z: 20

    Rectangle {
      anchors.fill: parent
      radius: Style.radiusM
      color: Qt.alpha(Color.mSurface, root.frameOpacity)
      border.color: Qt.alpha(Color.mOutline, 0.55)

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      }

      ColumnLayout {
        id: chooserLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Chooser Header (fixed at top)
        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          NIcon {
            icon: "window"
            pointSize: Style.fontSizeS
            color: Color.mPrimary
          }

          NText {
            Layout.fillWidth: true
            text: root.getAppName(root.chooserAppId)
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            elide: Text.ElideRight
          }

          NIconButton {
            baseSize: 22
            icon: "x"
            tooltipText: I18n.tr("common.close") ?? "Close"
            onClicked: root.resetChooser()
          }
        }

        // Header Divider
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Color.mOutline
          opacity: 0.5
        }

        // Candidate List (scrollable when candidate count exceeds available height)
        Flickable {
          id: candidateFlickable
          Layout.fillWidth: true
          Layout.preferredHeight: root.effectiveCandidateListHeight
          contentWidth: width
          contentHeight: candidateColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          interactive: contentHeight > height

          Column {
            id: candidateColumn
            width: candidateFlickable.width
            spacing: root.candidateSpacing

            Repeater {
              model: root.chooserCandidates

              delegate: Rectangle {
                id: candidateRow
                required property var modelData
                required property int index

                width: candidateColumn.width
                height: root.candidateRowHeight
                radius: Style.radiusS
                color: candidateMouseArea.containsMouse ? root.hoverColor : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  spacing: 8

                  Image {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    source: root.getAppIcon(root.chooserAppId)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                  }

                  NText {
                    Layout.fillWidth: true
                    text: (modelData.title && modelData.title.length > 0) ? modelData.title : (modelData.appId || ("Window " + modelData.id))
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: candidateMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (typeof EdgeShelfService !== "undefined" && EdgeShelfService) {
                      EdgeShelfService.chooseWindow(root.chooserAppId, modelData.id, root.screen);
                    }
                    root.resetChooser();
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
