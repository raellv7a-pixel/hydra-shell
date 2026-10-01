import QtQuick
import QtQuick.Layouts
import Quickshell
import "MonitorLayout/MonitorGeometry.js" as MonitorGeometry
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  spacing: Style.marginM
  Layout.fillWidth: true
  implicitHeight: (root.activeSubTab === 0 ? tab0Layout.implicitHeight : tab1Layout.implicitHeight) + subTabBar.implicitHeight + Style.marginL * 3

  readonly property var outputs: MonitorService.draftOutputs
  readonly property var selectedOutput: MonitorService.getSelectedOutput()
  readonly property string selectedOutputId: MonitorService.selectedOutputId
  property int activeSubTab: 0

  property real scenePadding: 20 * Style.uiScaleRatio
  property bool isDragging: false
  property var frozenCanvasSize: null
  property real frozenSceneScale: 1
  property real frozenSceneOffsetX: 0
  property real frozenSceneOffsetY: 0
  property real dragStartCanvasX: 0
  property real dragStartCanvasY: 0

  function clearDragState() {
    root.isDragging = false;
    root.frozenSceneBounds = null;
    root.frozenCanvasSize = null;
  }

  readonly property var sceneBounds: computeSceneBounds(outputs)
  readonly property real viewportWidth: sceneScrollWrapper ? sceneScrollWrapper.availableWidth : 0
  readonly property real sceneScale: computeSceneScale()
  readonly property var requiredSceneSize: (root.isDragging && root.frozenCanvasSize) ? root.frozenCanvasSize : root.computeRequiredSceneSize()

  readonly property var activeSceneBounds: (root.isDragging && root.frozenSceneBounds) ? root.frozenSceneBounds : root.sceneBounds
  readonly property real activeSceneScale: (root.isDragging && root.frozenSceneBounds) ? root.frozenSceneScale : root.sceneScale
  readonly property real activeSceneOffsetX: (root.isDragging && root.frozenSceneBounds) ? root.frozenSceneOffsetX : root.sceneOffsetX
  readonly property real activeSceneOffsetY: (root.isDragging && root.frozenSceneBounds) ? root.frozenSceneOffsetY : root.sceneOffsetY

  function computeSceneBounds(list) {
    if (!list || list.length === 0) {
      return {
        "minX": 0,
        "minY": 0,
        "maxX": 1920,
        "maxY": 1080,
        "width": 1920,
        "height": 1080
      };
    }
    var firstRect = MonitorGeometry.getRect(list[0]);
    var minX = list[0].x;
    var minY = list[0].y;
    var maxX = list[0].x + firstRect.width;
    var maxY = list[0].y + firstRect.height;

    for (var i = 1; i < list.length; i++) {
      var output = list[i];
      var rect = MonitorGeometry.getRect(output);
      minX = Math.min(minX, output.x);
      minY = Math.min(minY, output.y);
      maxX = Math.max(maxX, output.x + rect.width);
      maxY = Math.max(maxY, output.y + rect.height);
    }

    return {
      "minX": minX,
      "minY": minY,
      "maxX": maxX,
      "maxY": maxY,
      "width": Math.max(1, maxX - minX),
      "height": Math.max(1, maxY - minY)
    };
  }

  readonly property real sceneFitFraction: 0.72

  readonly property real viewportHeight: {
    var usableWidth = (root.viewportWidth - scenePadding * 2) * sceneFitFraction;
    if (usableWidth <= 0)
      return 280;
    var arrangementHeight = usableWidth * (sceneBounds.height / sceneBounds.width);
    return Math.max(280, Math.min(560, arrangementHeight / sceneFitFraction + scenePadding * 2));
  }

  readonly property real sceneOffsetX: Math.max(scenePadding, (root.viewportWidth - sceneBounds.width * sceneScale) / 2)
  readonly property real sceneOffsetY: Math.max(scenePadding, (root.viewportHeight - sceneBounds.height * sceneScale) / 2)

  function computeSceneScale() {
    var availableWidth = (root.viewportWidth - (scenePadding * 2)) * sceneFitFraction;
    var availableHeight = (root.viewportHeight - (scenePadding * 2)) * sceneFitFraction;
    if (availableWidth <= 0 || availableHeight <= 0)
      return 1;
    return Math.max(0.02, Math.min(availableWidth / sceneBounds.width, availableHeight / sceneBounds.height));
  }

  function computeRequiredSceneSize() {
    var maxX = root.viewportWidth;
    var maxY = root.viewportHeight;
    for (var i = 0; i < outputs.length; i++) {
      var output = outputs[i];
      var rect = MonitorGeometry.getRect(output);
      var tileRight = layoutToCanvasX(output.x) + Math.max(90, rect.width * sceneScale);
      var tileBottom = layoutToCanvasY(output.y) + Math.max(55, rect.height * sceneScale);
      maxX = Math.max(maxX, tileRight + scenePadding);
      maxY = Math.max(maxY, tileBottom + scenePadding);
    }
    return {
      "width": maxX,
      "height": maxY
    };
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

  function resolutionModel(output) {
    if (!output || !output.availableModes)
      return [];
    var model = [];
    var modes = output.availableModes;
    for (var i = 0; i < modes.length; i++) {
      var m = modes[i];
      if (typeof m === "string") {
        model.push({
                     key: m,
                     name: m
                   });
      } else if (typeof m === "object") {
        model.push({
                     key: m.id,
                     name: m.label || (m.width + "x" + m.height + " @ " + Math.round(m.refresh) + " Hz")
                   });
      }
    }
    return model;
  }

  // Sub-tab Bar
  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    currentIndex: root.activeSubTab
    distributeEvenly: true

    NTabButton {
      text: "Arranjo Visual das Telas"
      tabIndex: 0
      checked: root.activeSubTab === 0
      onClicked: root.activeSubTab = 0
    }
    NTabButton {
      text: "Linhas do hyprland.conf"
      tabIndex: 1
      checked: root.activeSubTab === 1
      onClicked: root.activeSubTab = 1
    }
  }

  // ==========================================
  // TAB 0: ARRANJO VISUAL (EM CAMADAS VERTICAIS)
  // ==========================================
  ColumnLayout {
    id: tab0Layout
    Layout.fillWidth: true
    visible: root.activeSubTab === 0
    spacing: Style.marginM

    // Transaction Countdown / Confirmation Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 64
      visible: MonitorService.transactionState === "confirming"
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
            text: "Manter nova configuração de telas?"
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            pointSize: Style.fontSizeM
          }
          NText {
            text: "Revertendo automaticamente em " + MonitorService.confirmationRemainingSeconds + " segundos se não for confirmada..."
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }
        }

        NButton {
          text: "Manter (" + MonitorService.confirmationRemainingSeconds + "s)"
          icon: "check"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: MonitorService.keepLayout()
        }

        NButton {
          text: "Reverter Agora"
          icon: "arrow-back"
          backgroundColor: Color.mError
          textColor: Color.mOnError
          onClicked: MonitorService.rollback()
        }
      }
    }

    // Rollback Failed Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 64
      visible: MonitorService.transactionState === "rollback_failed"
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
          text: "Falha ao restaurar o layout anterior. O snapshot seguro continua preservado na memória."
          color: Color.mOnErrorContainer || Color.mError
          pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
        }

        NButton {
          text: "Tentar Reverter Novamente"
          icon: "refresh"
          backgroundColor: Color.mError
          textColor: Color.mOnError
          onClicked: MonitorService.retryRollback()
        }
      }
    }

    // Applying / Verifying / Reverting Status Banner
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      visible: MonitorService.transactionState === "preparing" || MonitorService.transactionState === "applying" || MonitorService.transactionState === "verifying" || MonitorService.transactionState === "reverting" || MonitorService.transactionState === "rollback_verifying"
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
          text: MonitorService.transactionState === "preparing" ? "Capturando a configuração atual antes de aplicar..." : MonitorService.transactionState === "applying" ? "Aplicando configuração de monitores no compositor..." : MonitorService.transactionState === "verifying" ? "Verificando integridade das saídas de vídeo..." :
                                                                                                                                                                                                                                                                                      "Revertendo para a configuração anterior segura..."
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
        }
      }
    }

    // ----------------------------------------------------
    // 1. ARRANGEMENT CANVAS (FULL WIDTH AT TOP)
    // ----------------------------------------------------
    NScrollView {
      id: sceneScrollWrapper
      Layout.fillWidth: true
      Layout.preferredHeight: root.viewportHeight
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
            for (var x = 0; x < width; x += 40) {
              ctx.moveTo(x, 0);
              ctx.lineTo(x, height);
            }
            for (var y = 0; y < height; y += 40) {
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
            readonly property var output: modelData
            readonly property bool isSelected: output.outputId === root.selectedOutputId
            readonly property var logicalRect: MonitorGeometry.getRect(output)

            x: root.layoutToCanvasX(output.x)
            y: root.layoutToCanvasY(output.y)
            width: Math.max(90, logicalRect.width * root.activeSceneScale)
            height: Math.max(55, logicalRect.height * root.activeSceneScale)

            color: isSelected ? Qt.alpha(Color.mPrimary, 0.28) : Qt.alpha(Color.mSurfaceVariant, 0.65)
            border.color: isSelected ? Color.mPrimary : Color.mOutline
            border.width: isSelected ? 2 : 1
            radius: Style.radiusM

            Behavior on x {
              enabled: !dragArea.drag.active && !root.isDragging
              NumberAnimation {
                duration: 120
              }
            }
            Behavior on y {
              enabled: !dragArea.drag.active && !root.isDragging
              NumberAnimation {
                duration: 120
              }
            }

            // Primary Monitor Badge
            Rectangle {
              visible: !!output.isPrimary
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: 6
              height: 20
              width: primaryBadgeLayout.implicitWidth + 10
              color: Color.mPrimary
              radius: 4

              RowLayout {
                id: primaryBadgeLayout
                anchors.centerIn: parent
                spacing: 3
                NIcon {
                  icon: "star"
                  color: Color.mOnPrimary
                  pointSize: Style.fontSizeXXS
                }
                NText {
                  text: "Principal"
                  pointSize: Style.fontSizeXXS
                  color: Color.mOnPrimary
                  font.weight: Style.fontWeightBold
                }
              }
            }

            MouseArea {
              id: dragArea
              anchors.fill: parent
              preventStealing: true
              drag.target: parent
              drag.axis: Drag.XAndYAxis
              drag.minimumX: root.scenePadding
              drag.minimumY: root.scenePadding
              drag.maximumX: sceneCanvas.width - monitorTile.width - root.scenePadding
              drag.maximumY: sceneCanvas.height - monitorTile.height - root.scenePadding

              onPressed: {
                root.dragStartCanvasX = monitorTile.x;
                root.dragStartCanvasY = monitorTile.y;
                root.frozenCanvasSize = {
                  "width": root.requiredSceneSize.width,
                  "height": root.requiredSceneSize.height
                };
                root.frozenSceneBounds = JSON.parse(JSON.stringify(root.sceneBounds));
                root.frozenSceneScale = root.sceneScale;
                root.frozenSceneOffsetX = root.sceneOffsetX;
                root.frozenSceneOffsetY = root.sceneOffsetY;
                root.isDragging = true;
                MonitorService.selectOutput(output.outputId);
              }

              onReleased: {
                if (Math.abs(monitorTile.x - root.dragStartCanvasX) <= 1 && Math.abs(monitorTile.y - root.dragStartCanvasY) <= 1) {
                  root.clearDragState();
                  return;
                }
                var snapScale = root.frozenSceneScale;
                var snapOffsetX = root.frozenSceneOffsetX;
                var snapOffsetY = root.frozenSceneOffsetY;
                var snapBounds = root.frozenSceneBounds || root.sceneBounds;

                var droppedX = snapBounds.minX + ((monitorTile.x - snapOffsetX) / snapScale);
                var droppedY = snapBounds.minY + ((monitorTile.y - snapOffsetY) / snapScale);

                var currentOutputs = JSON.parse(JSON.stringify(root.outputs));
                var activeIndex = -1;
                for (var i = 0; i < currentOutputs.length; i++) {
                  if (currentOutputs[i].outputId === output.outputId) {
                    activeIndex = i;
                    break;
                  }
                }

                if (activeIndex >= 0) {
                  var activeTile = currentOutputs[activeIndex];
                  activeTile.x = Math.round(droppedX);
                  activeTile.y = Math.round(droppedY);

                  var otherOutputs = [];
                  for (var j = 0; j < currentOutputs.length; j++) {
                    if (j !== activeIndex && currentOutputs[j].active !== false && !currentOutputs[j].disabled) {
                      otherOutputs.push(currentOutputs[j]);
                    }
                  }

                  if (otherOutputs.length > 0) {
                    // 1. Magnetic snap to nearest edge requiring overlap
                    var snapped = MonitorGeometry.snapToNearestEdge(activeTile, otherOutputs, 32);
                    activeTile.x = snapped.x;
                    activeTile.y = snapped.y;

                    // 2. Far drop attached flush: ensure no enabled monitor is disconnected
                    if (!MonitorGeometry.touchesAny(activeTile, otherOutputs)) {
                      var attached = MonitorGeometry.attachFlush(activeTile, otherOutputs);
                      activeTile.x = attached.x;
                      activeTile.y = attached.y;
                    }

                    // 3. Tidy gaps
                    currentOutputs[activeIndex] = activeTile;
                    currentOutputs = MonitorGeometry.tidyGaps(currentOutputs, 24);
                  }

                  // 4. Rebase chosen main to (0,0) preserving relative positions
                  var primaryId = MonitorService.primaryOutputId || (root.selectedOutput && root.selectedOutput.isPrimary ? root.selectedOutput.outputId : "");
                  currentOutputs = MonitorGeometry.rebaseToPrimary(currentOutputs, primaryId);

                  MonitorService.commitLayout(currentOutputs, primaryId);
                }

                root.clearDragState();
              }
              onCanceled: root.clearDragState()
            }

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2

              NText {
                text: output.name
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: monitorTile.isSelected ? Color.mPrimary : Color.mOnSurface
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: output.width + "x" + output.height + (output.refresh ? ("@" + Math.round(output.refresh) + "Hz") : "")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }
            }
          }
        }
      }
    }

    Item {
      Layout.preferredHeight: Style.marginS
    }

    // ----------------------------------------------------
    // 2. INSPECTOR & CONTROLS (FULL WIDTH STACKED BELOW)
    // ----------------------------------------------------
    NText {
      text: root.selectedOutput ? ("Ajustes do Monitor: " + root.selectedOutput.name + " (" + (root.selectedOutput.model || root.selectedOutput.make || "Monitor") + ")") : "Ajustes do Monitor"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM
      visible: root.selectedOutput !== null

      NToggle {
        Layout.fillWidth: true
        label: "Ativar Monitor"
        description: "Habilita ou desabilita a saída de vídeo deste monitor"
        enabled: !MonitorService.isBusy
        checked: root.selectedOutput ? (root.selectedOutput.active !== false && !root.selectedOutput.disabled) : true
        onToggled: checked => {
                     if (root.selectedOutput) {
                       MonitorService.updateOutput(root.selectedOutput.outputId, {
                                                     "active": checked,
                                                     "disabled": !checked
                                                   });
                     }
                   }
      }

      // Explicit Main Monitor Control
      NButton {
        Layout.fillWidth: true
        text: (root.selectedOutput && root.selectedOutput.isPrimary) ? "Monitor Principal Definido (Origem 0, 0)" : "Definir como Monitor Principal"
        icon: "star"
        backgroundColor: (root.selectedOutput && root.selectedOutput.isPrimary) ? Qt.alpha(Color.mPrimary, 0.2) : Color.mSurfaceVariant
        textColor: (root.selectedOutput && root.selectedOutput.isPrimary) ? Color.mPrimary : Color.mOnSurfaceVariant
        enabled: !MonitorService.isBusy && root.selectedOutput && root.selectedOutput.active !== false && !root.selectedOutput.disabled && !root.selectedOutput.isPrimary
        onClicked: {
          if (root.selectedOutput) {
            MonitorService.setPrimaryOutput(root.selectedOutput.outputId);
          }
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Espelhar Tela (Mirror)"
        description: "Espelha o conteúdo exibido em outro monitor"
        enabled: !MonitorService.isBusy
        currentKey: root.selectedOutput ? (root.selectedOutput.mirror || "") : ""
        model: {
          var list = [
                {
                  key: "",
                  name: "Nenhum (Tela Independente)"
                }
              ];
          for (var i = 0; i < root.outputs.length; i++) {
            var out = root.outputs[i];
            if (root.selectedOutput && out.outputId !== root.selectedOutput.outputId) {
              list.push({
                          key: out.outputId,
                          name: "Espelhar " + out.name
                        });
            }
          }
          return list;
        }
        onSelected: key => {
                      if (root.selectedOutput) {
                        MonitorService.updateOutput(root.selectedOutput.outputId, {
                                                      "mirror": key
                                                    });
                      }
                    }
      }

      NComboBox {
        id: resCombo
        Layout.fillWidth: true
        label: "Resolução & Taxa de Atualização"
        description: "Modos de exibição suportados pelo compositor para esta tela"
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

      // Resolution-aware Discrete Scale Ladder ComboBox
      NComboBox {
        Layout.fillWidth: true
        label: "Escala do Monitor"
        description: "Selecione o fator de escala discreto (DPI) baseado na resolução desta tela"
        visible: !CompositorService.isSway
        enabled: !MonitorService.isBusy
        currentKey: String(root.selectedOutput ? (root.selectedOutput.scale || 1.0) : 1.0)
        model: {
          if (!root.selectedOutput)
            return [
                  {
                    key: "1",
                    name: "100% (1.0x)"
                  }
                ];
          var ladder = MonitorGeometry.getScaleLadder(root.selectedOutput.width, root.selectedOutput.height, root.selectedOutput.transform);
          var list = [];
          for (var i = 0; i < ladder.length; i++) {
            var s = ladder[i];
            var pct = Math.round(s * 100);
            list.push({
                        key: String(s),
                        name: pct + "% (" + s + "x)"
                      });
          }
          return list;
        }
        onSelected: key => {
                      if (root.selectedOutput) {
                        var parsed = parseFloat(key) || 1.0;
                        MonitorService.updateOutput(root.selectedOutput.outputId, {
                                                      "scale": parsed
                                                    });
                      }
                    }
      }
      NValueSlider {
        visible: CompositorService.isSway
        Layout.fillWidth: true
        label: "Escala do Monitor"
        description: "Ajusta o fator de escala (DPI) para elementos e fontes nesta tela"
        enabled: !MonitorService.isBusy
        from: 0.8
        to: 2.0
        stepSize: 0.05
        value: root.selectedOutput ? (root.selectedOutput.scale || 1.0) : 1.0
        onMoved: val => {
                   if (root.selectedOutput) {
                     MonitorService.updateOutput(root.selectedOutput.outputId, {
                                                   "scale": Math.round(val * 100) / 100
                                                 });
                   }
                 }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Orientação / Rotação da Tela"
        description: "Gira a exibição do monitor em ângulos de 90 graus"
        enabled: !MonitorService.isBusy
        currentKey: String(root.selectedOutput ? (root.selectedOutput.transform || 0) : 0)
        model: [
          {
            key: "0",
            name: "Normal (0° - Paisagem)"
          },
          {
            key: "1",
            name: "90° Rotação (Retrato)"
          },
          {
            key: "2",
            name: "180° Invertido"
          },
          {
            key: "3",
            name: "270° Rotação"
          }
        ]
        onSelected: key => {
                      if (root.selectedOutput) {
                        MonitorService.updateOutput(root.selectedOutput.outputId, {
                                                      "transform": parseInt(key)
                                                    });
                      }
                    }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: "Posição Horizontal X (px)"
        enabled: !MonitorService.isBusy
        from: -3840
        to: 7680
        stepSize: 10
        value: root.selectedOutput ? (root.selectedOutput.x || 0) : 0
        onMoved: val => {
                   if (root.selectedOutput) {
                     MonitorService.updateOutputPosition(root.selectedOutput.outputId, Math.round(val), root.selectedOutput.y);
                   }
                 }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: "Posição Vertical Y (px)"
        enabled: !MonitorService.isBusy
        from: -2160
        to: 4320
        stepSize: 10
        value: root.selectedOutput ? (root.selectedOutput.y || 0) : 0
        onMoved: val => {
                   if (root.selectedOutput) {
                     MonitorService.updateOutputPosition(root.selectedOutput.outputId, root.selectedOutput.x, Math.round(val));
                   }
                 }
      }
    }

    Item {
      Layout.preferredHeight: Style.marginS
    }

    // ----------------------------------------------------
    // 3. ACTION BAR (FULL WIDTH AT BOTTOM)
    // ----------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        text: "Aplicar Agora"
        icon: "check"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: !MonitorService.isBusy
        onClicked: MonitorService.applyLayout()
      }

      NButton {
        text: "Salvar no Hyprland"
        icon: "device-floppy"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: !MonitorService.isBusy && MonitorService.transactionState === "idle"
        onClicked: MonitorService.saveToHyprlandConfig()
      }

      NButton {
        text: "Copiar Configuração do Hyprland"
        icon: "copy"
        backgroundColor: Color.mSurfaceVariant
        textColor: Color.mOnSurfaceVariant
        onClicked: {
          var snippet = MonitorService.generateConfigSnippet();
          if (snippet) {
            Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]);
            ToastService.showNotice("Configuração Copiada", "Linhas de monitor salvas na área de transferência!", "copy");
          }
        }
      }

      Item {
        Layout.fillWidth: true
      } // Spacer

      NButton {
        text: "Restaurar Padrão"
        icon: "refresh"
        backgroundColor: Color.mSurfaceVariant
        textColor: Color.mOnSurfaceVariant
        enabled: !MonitorService.isBusy
        onClicked: MonitorService.resetDraftOutputs()
      }
    }
  }

  // ==========================================
  // TAB 1: CONFIGURAÇÃO DO HYPRLAND
  // ==========================================
  ColumnLayout {
    id: tab1Layout
    Layout.fillWidth: true
    visible: root.activeSubTab === 1
    spacing: Style.marginM
    NText {
      text: "Código de Configuração dos Monitores"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    NText {
      text: "Confira abaixo os códigos gerados para salvar o layout de monitores permanentemente no Hyprland (Lua ou conf):"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    NText {
      text: "Sintaxe Lua (Hyprland 0.55+ em ~/.config/hypr/hydra-shell/monitors.lua):"
      pointSize: Style.fontSizeS
      font.weight: Style.fontWeightBold
      color: Color.mPrimary
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 140
      color: Qt.alpha(Color.mSurface, 0.9)
      border.color: Color.mOutline
      border.width: Style.borderS
      radius: Style.radiusM

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.marginM
        contentWidth: luaCodeText.implicitWidth
        contentHeight: luaCodeText.implicitHeight
        clip: true

        NText {
          id: luaCodeText
          text: MonitorService.generateLuaConfigSnippet() || "-- Nenhum monitor"
          font.family: "monospace"
          pointSize: Style.fontSizeS
          color: Color.mPrimary
        }
      }
    }

    NText {
      text: "Sintaxe Legada (para ~/.config/hypr/hyprland.conf):"
      pointSize: Style.fontSizeS
      font.weight: Style.fontWeightBold
      color: Color.mOnSurfaceVariant
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 110
      color: Qt.alpha(Color.mSurface, 0.9)
      border.color: Color.mOutline
      border.width: Style.borderS
      radius: Style.radiusM

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.marginM
        contentWidth: configCodeText.implicitWidth
        contentHeight: configCodeText.implicitHeight
        clip: true

        NText {
          id: configCodeText
          text: MonitorService.generateConfigSnippet() || "# Nenhum monitor"
          font.family: "monospace"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        text: "Salvar em monitors.lua"
        icon: "device-floppy"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: !MonitorService.isBusy && MonitorService.transactionState === "idle"
        onClicked: MonitorService.saveToHyprlandConfig()
      }

      NButton {
        text: "Copiar Código Lua"
        icon: "copy"
        backgroundColor: Color.mSurfaceVariant
        textColor: Color.mOnSurfaceVariant
        onClicked: {
          var snippet = MonitorService.generateLuaConfigSnippet();
          if (snippet) {
            Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]);
            ToastService.showNotice("Configuração Copiada", "Código Lua salvo na área de transferência!", "copy");
          }
        }
      }
    }
  }
}
