pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../Settings/Tabs/Display/MonitorLayout/MonitorGeometry.js" as MonitorGeometry
import qs.Commons
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  // Public contract properties
  readonly property bool blocked: baselineOutputs.length === 0 || isDirty || isConfirming || isSettling || isRollbackFailed || isPersisting || hasPersistenceError
  readonly property string summary: computeSummary()
  readonly property bool hasPersistenceError: MonitorService.persistenceError !== ""

  // Fine-grained states for wizard integration
  readonly property bool isDirty: {
    if (!baselineOutputs || baselineOutputs.length === 0)
      return false;
    return !MonitorGeometry.layoutsMatch(baselineOutputs, MonitorService.draftOutputs);
  }
  readonly property bool isConfirming: MonitorService.transactionState === "confirming"
  readonly property bool isSettling: MonitorService.isSettling
  readonly property bool isBusy: MonitorService.isBusy
  readonly property bool isRollbackFailed: MonitorService.transactionState === "rollback_failed"
  readonly property bool isPersisting: MonitorService.isPersisting

  signal discardCompleted

  // Internal session baseline & state
  property var initialDraftSnapshot: []
  property bool hadInitialDraftChanges: false
  property var baselineOutputs: []
  property var outputs: MonitorService.draftOutputs
  property string selectedOutputId: MonitorService.selectedOutputId
  readonly property var selectedOutput: MonitorService.getSelectedOutput()

  property real scenePadding: 16 * Style.uiScaleRatio
  property var dragState: null
  property var dragPosition: null
  property bool dragMoved: false
  readonly property bool isDragging: dragState !== null
  readonly property real sceneFitFraction: 0.8
  readonly property real minimumSceneScale: 0.02 * Style.uiScaleRatio
  readonly property real maximumSceneScale: 0.22 * Style.uiScaleRatio
  readonly property var sceneBounds: MonitorGeometry.computeSceneBounds(root.outputs)
  readonly property real viewportWidth: sceneScrollWrapper ? (sceneScrollWrapper.availableWidth > 0 ? sceneScrollWrapper.availableWidth : stepScrollView.availableWidth) : 400
  readonly property real viewportHeight: root.isDragging ? root.dragState.viewportHeight :
                                         Math.max(180 * Style.uiScaleRatio, Math.min(280 * Style.uiScaleRatio,
                                         root.viewportWidth * sceneBounds.height / Math.max(1, sceneBounds.width) + scenePadding * 2))
  readonly property var viewport: MonitorGeometry.fitViewport(sceneBounds, viewportWidth, viewportHeight,
                                                            scenePadding, minimumSceneScale, maximumSceneScale, sceneFitFraction)
  readonly property var activeSceneBounds: root.isDragging ? root.dragState.bounds : root.sceneBounds
  readonly property real activeSceneScale: root.isDragging ? root.dragState.scale : root.viewport.scale
  readonly property real activeSceneOffsetX: root.isDragging ? root.dragState.offsetX : root.viewport.offsetX
  readonly property real activeSceneOffsetY: root.isDragging ? root.dragState.offsetY : root.viewport.offsetY
  readonly property var requiredSceneSize: root.isDragging ? root.dragState.canvasSize : root.computeRequiredSceneSize()

  spacing: Style.marginM

  Component.onCompleted: {
    // Capture existing draft so manual cancel can safely restore it
    if (MonitorService.draftOutputs && MonitorService.draftOutputs.length > 0) {
      root.initialDraftSnapshot = JSON.parse(JSON.stringify(MonitorService.draftOutputs));
    }
    // Onboarding initializes its active baseline from the committed system layout (originalOutputs)
    // leaving preexisting unapplied drafts in Settings intact if cancelled.
    if (MonitorService.originalOutputs && MonitorService.originalOutputs.length > 0) {
      root.baselineOutputs = JSON.parse(JSON.stringify(MonitorService.originalOutputs));
      root.hadInitialDraftChanges = root.initialDraftSnapshot.length > 0 && !MonitorGeometry.layoutsMatch(root.initialDraftSnapshot, root.baselineOutputs);
      // Ensure wizard starts from the committed system configuration
      MonitorService.commitLayout(JSON.parse(JSON.stringify(MonitorService.originalOutputs)), MonitorService.primaryOutputId);
    }
  }

  Connections {
    target: MonitorService
    function onOriginalOutputsChanged() {
      if (root.baselineOutputs.length === 0 && MonitorService.originalOutputs.length > 0) {
        root.baselineOutputs = JSON.parse(JSON.stringify(MonitorService.originalOutputs));
        root.hadInitialDraftChanges = root.initialDraftSnapshot.length > 0 && !MonitorGeometry.layoutsMatch(root.initialDraftSnapshot, root.baselineOutputs);
      }
    }
    function onLayoutConfirmed() {
      // Update baseline after keep/confirm succeeds
      if (MonitorService.originalOutputs && MonitorService.originalOutputs.length > 0) {
        root.baselineOutputs = JSON.parse(JSON.stringify(MonitorService.originalOutputs));
      } else {
        root.baselineOutputs = JSON.parse(JSON.stringify(MonitorService.draftOutputs));
      }
    }
    function onTransactionStateChanged() {
      if (MonitorService.transactionState === "idle" && (!root.baselineOutputs || root.baselineOutputs.length === 0)) {
        if (MonitorService.originalOutputs && MonitorService.originalOutputs.length > 0) {
          root.baselineOutputs = JSON.parse(JSON.stringify(MonitorService.originalOutputs));
        }
      }
    }
  }

  function discardDraft() {
    if (root.isSettling) {
      return false;
    }

    if (root.isConfirming) {
      MonitorService.rollback();
      return false;
    }

    if (root.isRollbackFailed) {
      return false;
    }

    if (root.hadInitialDraftChanges && root.initialDraftSnapshot.length > 0) {
      MonitorService.commitLayout(JSON.parse(JSON.stringify(root.initialDraftSnapshot)), MonitorGeometry.derivePrimary(root.initialDraftSnapshot)?.outputId || "");
    } else if (root.baselineOutputs && root.baselineOutputs.length > 0) {
      MonitorService.commitLayout(JSON.parse(JSON.stringify(root.baselineOutputs)), MonitorGeometry.derivePrimary(root.baselineOutputs)?.outputId || "");
    } else {
      MonitorService.resetDraftOutputs();
    }

    root.discardCompleted();
    return true;
  }

  function computeSummary() {
    var outs = root.outputs || [];
    var activeList = outs.filter(function(o) { return o && o.active !== false && !o.disabled; });
    var count = activeList.length;
    var primary = activeList.find(function(o) { return o.isPrimary || (o.x === 0 && o.y === 0); });
    var primaryName = primary ? (primary.name || primary.outputId) : (activeList[0] ? (activeList[0].name || activeList[0].outputId) : "");

    if (count <= 1) {
      if (activeList.length === 1) {
        var m = activeList[0];
        return (m.name || m.outputId) + " • " + m.width + "x" + m.height + "@" + Math.round(m.refresh) + "Hz (" + Math.round((m.scale || 1.0) * 100) + "%)";
      }
      return I18n.tr("setup.hydra.displays.summary-none");
    }

    return I18n.tr("setup.hydra.displays.summary-multi", {
      "count": count,
      "primary": primaryName
    });
  }

  function clearDragState() {
    root.dragState = null;
    root.dragPosition = null;
    root.dragMoved = false;
  }

  function computeRequiredSceneSize() {
    var maxX = root.viewportWidth;
    var maxY = root.viewportHeight;
    for (var i = 0; i < outputs.length; i++) {
      var rect = MonitorGeometry.getRect(outputs[i]);
      maxX = Math.max(maxX, layoutToCanvasX(rect.x + rect.width) + scenePadding);
      maxY = Math.max(maxY, layoutToCanvasY(rect.y + rect.height) + scenePadding);
    }
    return { width: maxX, height: maxY };
  }

  function layoutToCanvasX(val) {
    return activeSceneOffsetX + ((val - activeSceneBounds.minX) * activeSceneScale);
  }
  function layoutToCanvasY(val) {
    return activeSceneOffsetY + ((val - activeSceneBounds.minY) * activeSceneScale);
  }
  function canvasToLayoutX(val) {
    return activeSceneBounds.minX + ((val - activeSceneOffsetX) / activeSceneScale);
  }
  function canvasToLayoutY(val) {
    return activeSceneBounds.minY + ((val - activeSceneOffsetY) / activeSceneScale);
  }

  function beginDrag(mouseX, mouseY) {
    var outputId = MonitorGeometry.outputAtPoint(root.outputs, canvasToLayoutX(mouseX), canvasToLayoutY(mouseY), root.selectedOutputId);
    if (!outputId)
      return;
    MonitorService.selectOutput(outputId);
    var output = root.selectedOutput;
    if (!output)
      return;
    root.dragState = {
      outputId: outputId, x: output.x, y: output.y, mouseX: mouseX, mouseY: mouseY,
      bounds: root.sceneBounds, scale: root.viewport.scale,
      offsetX: root.viewport.offsetX, offsetY: root.viewport.offsetY,
      canvasSize: root.requiredSceneSize, viewportHeight: root.viewportHeight
    };
    root.dragPosition = { x: output.x, y: output.y };
    root.dragMoved = false;
  }

  function moveDrag(mouseX, mouseY) {
    if (!root.isDragging)
      return;
    if (!root.dragMoved && Math.max(Math.abs(mouseX - root.dragState.mouseX), Math.abs(mouseY - root.dragState.mouseY)) < canvasPointer.drag.threshold)
      return;
    root.dragMoved = true;
    root.dragPosition = MonitorGeometry.dragPosition(root.dragState, mouseX, mouseY);
  }

  function finishDrag() {
    if (!root.isDragging)
      return;
    var outputId = root.dragState.outputId;
    var position = root.dragPosition;
    var moved = root.dragMoved;
    root.clearDragState();
    if (!moved)
      return;
    var currentOutputs = JSON.parse(JSON.stringify(root.outputs));
    var activeTile = currentOutputs.find(output => output.outputId === outputId);
    if (!activeTile)
      return;
    activeTile.x = position.x;
    activeTile.y = position.y;
    var otherOutputs = currentOutputs.filter(output => output.outputId !== outputId && output.active !== false && !output.disabled);
    if (otherOutputs.length > 0 && activeTile.active !== false && !activeTile.disabled) {
      var snapped = MonitorGeometry.snapToNearestEdge(activeTile, otherOutputs, 32);
      activeTile.x = snapped.x;
      activeTile.y = snapped.y;
      if (!MonitorGeometry.touchesAny(activeTile, otherOutputs)) {
        var attached = MonitorGeometry.attachFlush(activeTile, otherOutputs);
        activeTile.x = attached.x;
        activeTile.y = attached.y;
      }
      currentOutputs = MonitorGeometry.tidyGaps(currentOutputs, 24);
    }
    MonitorService.commitLayout(currentOutputs, MonitorService.primaryOutputId);
  }

  function resolutionModel(output) {
    if (!output || !output.availableModes)
      return [];
    var model = [];
    var modes = output.availableModes;
    for (var i = 0; i < modes.length; i++) {
      var m = modes[i];
      if (typeof m === "string") {
        model.push({ key: m, name: m });
      } else if (typeof m === "object") {
        model.push({
          key: m.id,
          name: m.label || (m.width + "x" + m.height + " @ " + Math.round(m.refresh) + " Hz")
        });
      }
    }
    return model;
  }

  // Header
  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    spacing: Style.marginM

    Rectangle {
      width: 40
      height: 40
      radius: Style.radiusL
      color: Color.mSurfaceVariant
      opacity: 0.6

      NIcon {
        icon: "device-desktop"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
        anchors.centerIn: parent
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: I18n.tr("setup.hydra.displays.header")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mPrimary
      }

      NText {
        text: I18n.tr("setup.hydra.displays.subheader")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }
    }
  }

  // Scrollable Body
  NScrollView {
    id: stepScrollView
    Layout.fillWidth: true
    Layout.fillHeight: true
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AlwaysOff
    reserveScrollbarSpace: false
    showGradientMasks: false

    ColumnLayout {
      width: stepScrollView.availableWidth
      spacing: Style.marginM

      // Confirmation Banner (15s verification)
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        visible: root.isConfirming
        color: Qt.alpha(Color.mPrimary, 0.15)
        border.color: Color.mPrimary
        border.width: 1
        radius: Style.radiusM

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "alert-circle"
            color: Color.mPrimary
            pointSize: Style.fontSizeL
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            NText {
              text: I18n.tr("setup.hydra.displays.confirm-title")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              pointSize: Style.fontSizeM
            }
            NText {
              text: I18n.tr("setup.hydra.displays.confirm-desc", { "seconds": MonitorService.confirmationRemainingSeconds })
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
            }
          }

          SetupAction {
            text: I18n.tr("setup.hydra.displays.keep-button", { "seconds": MonitorService.confirmationRemainingSeconds })
            icon: "check"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            onClicked: {
              MonitorService.keepLayout();
              MonitorService.saveToUmbrielConfig();
            }
          }

          SetupAction {
            text: I18n.tr("setup.hydra.displays.revert-now")
            icon: "arrow-back"
            backgroundColor: Color.mError
            textColor: Color.mOnError
            onClicked: MonitorService.rollback()
          }
        }
      }

      // Rollback Failed Warning
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        visible: root.isRollbackFailed
        color: Qt.alpha(Color.mError, 0.15)
        border.color: Color.mError
        border.width: 1
        radius: Style.radiusM

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "alert-triangle"
            color: Color.mError
            pointSize: Style.fontSizeL
          }

          NText {
            Layout.fillWidth: true
            text: I18n.tr("setup.hydra.displays.rollback-failed-desc")
            color: Color.mOnErrorContainer || Color.mError
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
          }

          SetupAction {
            text: I18n.tr("setup.hydra.displays.retry-rollback")
            icon: "refresh"
            backgroundColor: Color.mError
            textColor: Color.mOnError
            onClicked: MonitorService.retryRollback()
          }
        }
      }

      // Settling Status Banner
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: root.isSettling && !root.isConfirming
        color: Qt.alpha(Color.mSurfaceVariant, 0.85)
        border.color: Color.mOutline
        border.width: 1
        radius: Style.radiusM

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NBusyIndicator {
            running: true
          }

          NText {
            Layout.fillWidth: true
            text: MonitorService.transactionState === "preparing" ? I18n.tr("setup.hydra.displays.status-preparing") :
                  MonitorService.transactionState === "applying" ? I18n.tr("setup.hydra.displays.status-applying") :
                  MonitorService.transactionState === "verifying" ? I18n.tr("setup.hydra.displays.status-verifying") :
                  MonitorService.isPersisting ? I18n.tr("setup.hydra.displays.status-persisting") :
                  I18n.tr("setup.hydra.displays.status-reverting")
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
          }
        }
      }

      // Persistence Error Banner
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        visible: MonitorService.persistenceError !== "" && !root.isSettling
        color: Qt.alpha(Color.mError, 0.15)
        border.color: Color.mError
        border.width: 1
        radius: Style.radiusM

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "alert-triangle"
            color: Color.mError
            pointSize: Style.fontSizeM
          }

          NText {
            Layout.fillWidth: true
            text: I18n.tr("setup.hydra.displays.persist-error", { "error": MonitorService.persistenceError })
            color: Color.mOnErrorContainer || Color.mError
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
          }

          SetupAction {
            text: I18n.tr("setup.hydra.displays.retry-save")
            icon: "refresh"
            backgroundColor: Color.mError
            textColor: Color.mOnError
            onClicked: MonitorService.saveToUmbrielConfig()
          }
        }
      }

      // Connector Selector Chips (if multi-monitor)
      RowLayout {
        Layout.fillWidth: true
        visible: root.outputs.length > 1
        spacing: Style.marginS

        NText {
          text: I18n.tr("setup.hydra.displays.select-display")
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightBold
          color: Color.mOnSurfaceVariant
        }

        Repeater {
          model: root.outputs
          delegate: SetupAction {
            required property var modelData
            readonly property bool isSelected: modelData.outputId === root.selectedOutputId
            readonly property bool isPrimary: modelData.isPrimary || (modelData.x === 0 && modelData.y === 0)

            text: (modelData.name || modelData.outputId) + (isPrimary ? " ★" : "")
            backgroundColor: isSelected ? Color.mPrimary : Color.mSurfaceContainerHigh
            textColor: isSelected ? Color.mOnPrimary : Color.mOnSurface
            enabled: !MonitorService.isBusy
            onClicked: MonitorService.selectOutput(modelData.outputId)
          }
        }
      }

      // Multi-Monitor Canvas (Only shown when > 1 monitor exists)
      NScrollView {
        id: sceneScrollWrapper
        Layout.fillWidth: true
        Layout.preferredHeight: root.viewportHeight
        visible: root.outputs.length > 1
        clip: true

        Rectangle {
          id: sceneCanvas
          width: Math.max(root.viewportWidth, root.requiredSceneSize.width)
          height: Math.max(root.viewportHeight, root.requiredSceneSize.height)
          color: Qt.alpha(Color.mSurface, 0.5)
          border.color: Color.mOutline
          border.width: Style.borderS
          radius: Style.radiusM

          Canvas {
            anchors.fill: parent
            opacity: 0.12
            onPaint: {
              var ctx = getContext("2d");
              ctx.strokeStyle = Color.mOnSurface;
              ctx.lineWidth = 1;
              ctx.beginPath();
              for (var x = 0; x < width; x += 32) {
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
              }
              for (var y = 0; y < height; y += 32) {
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
              }
              ctx.stroke();
            }
          }

          Repeater {
            model: root.outputs

            delegate: Rectangle {
              id: monitorTile
              required property var modelData
              readonly property var output: modelData
              readonly property bool isSelected: output.outputId === root.selectedOutputId
              readonly property var logicalRect: MonitorGeometry.getRect(output)
              readonly property bool isDragged: root.isDragging && root.dragState.outputId === output.outputId
              readonly property bool isPrimary: output.isPrimary || (output.x === 0 && output.y === 0)

              x: root.layoutToCanvasX(isDragged && root.dragPosition ? root.dragPosition.x : logicalRect.x)
              y: root.layoutToCanvasY(isDragged && root.dragPosition ? root.dragPosition.y : logicalRect.y)
              width: logicalRect.width * root.activeSceneScale
              height: logicalRect.height * root.activeSceneScale
              z: isSelected ? 1 : 0

              radius: Style.radiusS
              color: isSelected ? Qt.alpha(Color.mPrimary, 0.25) : Qt.alpha(Color.mSurfaceContainerHigh, 0.8)
              border.color: isSelected ? Color.mPrimary : Color.mOutline
              border.width: isSelected ? Style.borderM : Style.borderS

              ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                RowLayout {
                  Layout.alignment: Qt.AlignHCenter
                  spacing: 4
                  NText {
                    text: output.name || output.outputId
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeS
                    color: isSelected ? Color.mPrimary : Color.mOnSurface
                  }
                  NIcon {
                    visible: isPrimary
                    icon: "star"
                    pointSize: Style.fontSizeXS
                    color: isSelected ? Color.mPrimary : Color.mOnSurfaceVariant
                  }
                }

                NText {
                  Layout.alignment: Qt.AlignHCenter
                  text: Math.round(output.width) + "x" + Math.round(output.height) + " (" + Math.round((output.scale || 1.0) * 100) + "%)"
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                }
              }
            }
          }

          MouseArea {
            id: canvasPointer
            anchors.fill: parent
            z: 2
            enabled: !MonitorService.isBusy
            preventStealing: true
            onPressed: mouse => root.beginDrag(mouse.x, mouse.y)
            onPositionChanged: mouse => {
              if (pressed)
                root.moveDrag(mouse.x, mouse.y);
            }
            onReleased: root.finishDrag()
            onCanceled: root.clearDragState()
          }
        }
      }

      // Selected Output Settings Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: root.selectedOutput ? (root.selectedOutput.name + " (" + (root.selectedOutput.model || root.selectedOutput.make || "Monitor") + ")") : I18n.tr("setup.hydra.displays.monitor-settings")
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }

        // Primary Display Button (for multi-monitor)
        SetupAction {
          visible: root.outputs.length > 1 && root.selectedOutput !== null
          text: (root.selectedOutput && (root.selectedOutput.isPrimary || (root.selectedOutput.x === 0 && root.selectedOutput.y === 0))) ?
                I18n.tr("setup.hydra.displays.primary-active") :
                I18n.tr("setup.hydra.displays.set-primary")
          icon: "star"
          backgroundColor: (root.selectedOutput && (root.selectedOutput.isPrimary || (root.selectedOutput.x === 0 && root.selectedOutput.y === 0))) ?
                           Qt.alpha(Color.mPrimary, 0.2) : Color.mSurfaceVariant
          textColor: (root.selectedOutput && (root.selectedOutput.isPrimary || (root.selectedOutput.x === 0 && root.selectedOutput.y === 0))) ?
                     Color.mPrimary : Color.mOnSurfaceVariant
          enabled: !MonitorService.isBusy && !!root.selectedOutput && !(root.selectedOutput.isPrimary || (root.selectedOutput.x === 0 && root.selectedOutput.y === 0))
          onClicked: {
            if (root.selectedOutput) {
              MonitorService.setPrimaryOutput(root.selectedOutput.outputId);
            }
          }
        }
      }

      // Monitor Configuration Controls
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        visible: root.selectedOutput !== null

        // Resolution & Refresh Rate
        NComboBox {
          id: resCombo
          Layout.fillWidth: true
          label: I18n.tr("setup.hydra.displays.resolution-label")
          description: I18n.tr("setup.hydra.displays.resolution-desc")
          enabled: !MonitorService.isBusy
          model: root.resolutionModel(root.selectedOutput)
          currentKey: root.selectedOutput ? (root.selectedOutput.modeId || (root.selectedOutput.width + "x" + root.selectedOutput.height + "@" + Math.round(root.selectedOutput.refresh))) : ""
          onSelected: key => {
            if (root.selectedOutput) {
              var modes = root.selectedOutput.availableModes || [];
              var matched = null;
              for (var i = 0; i < modes.length; i++) {
                if (modes[i].id === key || modes[i].key === key) {
                  matched = modes[i];
                  break;
                }
              }
              if (matched) {
                MonitorService.updateOutput(root.selectedOutput.outputId, {
                  "width": matched.width,
                  "height": matched.height,
                  "refresh": matched.refresh,
                  "modeId": matched.id
                });
              }
            }
          }
        }

        // Discrete Scale Ladder
        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("setup.hydra.displays.scale-label")
          description: I18n.tr("setup.hydra.displays.scale-desc")
          enabled: !MonitorService.isBusy
          currentKey: String(root.selectedOutput ? (root.selectedOutput.scale || 1.0) : 1.0)
          model: {
            if (!root.selectedOutput)
              return [{ key: "1", name: "100% (1.0x)" }];
            var ladder = MonitorGeometry.getScaleLadder(root.selectedOutput.width, root.selectedOutput.height, root.selectedOutput.transform);
            var list = [];
            for (var i = 0; i < ladder.length; i++) {
              var s = ladder[i];
              var pct = Math.round(s * 100);
              list.push({ key: String(s), name: pct + "% (" + s + "x)" });
            }
            return list;
          }
          onSelected: key => {
            if (root.selectedOutput) {
              var parsed = parseFloat(key) || 1.0;
              MonitorService.updateOutput(root.selectedOutput.outputId, { "scale": parsed });
            }
          }
        }

        // Orientation / Transform
        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("setup.hydra.displays.orientation-label")
          description: I18n.tr("setup.hydra.displays.orientation-desc")
          enabled: !MonitorService.isBusy
          currentKey: String(root.selectedOutput ? (root.selectedOutput.transform || 0) : 0)
          model: [
            { key: "0", name: I18n.tr("setup.hydra.displays.orient-normal") },
            { key: "1", name: I18n.tr("setup.hydra.displays.orient-90") },
            { key: "2", name: I18n.tr("setup.hydra.displays.orient-180") },
            { key: "3", name: I18n.tr("setup.hydra.displays.orient-270") }
          ]
          onSelected: key => {
            if (root.selectedOutput) {
              MonitorService.updateOutput(root.selectedOutput.outputId, { "transform": parseInt(key) });
            }
          }
        }
      }

      // Step Action Bar: Apply / Reset Draft
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        spacing: Style.marginM

        SetupAction {
          text: I18n.tr("setup.hydra.displays.apply-button")
          icon: "check"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          enabled: !MonitorService.isBusy && root.isDirty
          onClicked: MonitorService.applyLayout()
        }

        SetupAction {
          text: I18n.tr("setup.hydra.displays.reset-draft")
          icon: "refresh"
          backgroundColor: Color.mSurfaceVariant
          textColor: Color.mOnSurfaceVariant
          enabled: !MonitorService.isBusy && root.isDirty
          onClicked: root.discardDraft()
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: root.isDirty ? I18n.tr("setup.hydra.displays.dirty-hint") :
                root.isConfirming ? I18n.tr("setup.hydra.displays.confirming-hint") :
                I18n.tr("setup.hydra.displays.synced-hint")
          pointSize: Style.fontSizeS
          color: root.isDirty ? Color.mPrimary : Color.mOnSurfaceVariant
        }
      }
    }
  }
}
