pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "MonitorLayout/MonitorGeometry.js" as MonitorGeometry
import qs.Commons
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
  property var dragState: null
  property var dragPosition: null
  property bool dragMoved: false
  readonly property bool isDragging: dragState !== null
  readonly property real sceneFitFraction: 0.72
  readonly property real minimumSceneScale: 0.02 * Style.uiScaleRatio
  // Cap a 1920-wide tile at 480 UI pixels, including fully overlapping layouts.
  readonly property real maximumSceneScale: 0.25 * Style.uiScaleRatio
  readonly property var sceneBounds: MonitorGeometry.computeSceneBounds(root.outputs)
  readonly property real viewportWidth: sceneScrollWrapper.availableWidth
  readonly property real viewportHeight: root.isDragging ? root.dragState.viewportHeight :
                                         Math.max(280 * Style.uiScaleRatio, Math.min(560 * Style.uiScaleRatio,
                                         root.viewportWidth * sceneBounds.height / sceneBounds.width + scenePadding * 2))
  readonly property var viewport: MonitorGeometry.fitViewport(sceneBounds, viewportWidth, viewportHeight,
                                                            scenePadding, minimumSceneScale, maximumSceneScale, sceneFitFraction)
  readonly property var activeSceneBounds: root.isDragging ? root.dragState.bounds : root.sceneBounds
  readonly property real activeSceneScale: root.isDragging ? root.dragState.scale : root.viewport.scale
  readonly property real activeSceneOffsetX: root.isDragging ? root.dragState.offsetX : root.viewport.offsetX
  readonly property real activeSceneOffsetY: root.isDragging ? root.dragState.offsetY : root.viewport.offsetY
  readonly property var requiredSceneSize: root.isDragging ? root.dragState.canvasSize : root.computeRequiredSceneSize()

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
    // Replacing draftOutputs destroys delegates. Clear the canvas-owned gesture first.
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
      text: "Configuração outputs.toml"
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
            required property var modelData
            readonly property var output: modelData
            readonly property bool isSelected: output.outputId === root.selectedOutputId
            readonly property var logicalRect: MonitorGeometry.getRect(output)
            readonly property bool isDragged: root.isDragging && root.dragState.outputId === output.outputId

            x: root.layoutToCanvasX(isDragged && root.dragPosition ? root.dragPosition.x : logicalRect.x)
            y: root.layoutToCanvasY(isDragged && root.dragPosition ? root.dragPosition.y : logicalRect.y)
            width: logicalRect.width * root.activeSceneScale
            height: logicalRect.height * root.activeSceneScale
            z: isSelected ? 1 : 0

            color: isSelected ? Qt.alpha(Color.mPrimary, 0.28) : Qt.alpha(Color.mSurfaceVariant, 0.65)
            border.color: isSelected ? Color.mPrimary : Color.mOutline
            border.width: isSelected ? 2 : 1
            radius: Style.radiusM

            Behavior on x {
              enabled: !root.isDragging
              NumberAnimation {
                duration: 120
              }
            }
            Behavior on y {
              enabled: !root.isDragging
              NumberAnimation {
                duration: 120
              }
            }

            // Primary Monitor Badge
            Rectangle {
              visible: !!monitorTile.output.isPrimary
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

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2

              NText {
                text: monitorTile.output.name
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: monitorTile.isSelected ? Color.mPrimary : Color.mOnSurface
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: monitorTile.output.width + "x" + monitorTile.output.height + (monitorTile.output.refresh ? ("@" + Math.round(monitorTile.output.refresh) + "Hz") : "")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
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
        text: "Salvar na Umbriel"
        icon: "device-floppy"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: !MonitorService.isBusy && MonitorService.transactionState === "idle"
        onClicked: MonitorService.saveToUmbrielConfig()
      }

      NButton {
        text: "Copiar TOML"
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
  // TAB 1: CONFIGURAÇÃO DA UMBRIEL
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
      text: "Configuração gerada para o arquivo Hydra-owned hydra/outputs.toml. A aplicação valida o TOML antes de recarregar a Umbriel."
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }


    NText {
      text: "Umbriel — hydra/outputs.toml:"
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
        text: "Salvar em outputs.toml"
        icon: "device-floppy"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: !MonitorService.isBusy && MonitorService.transactionState === "idle"
        onClicked: MonitorService.saveToUmbrielConfig()
      }

      NButton {
        text: "Copiar TOML"
        icon: "copy"
        backgroundColor: Color.mSurfaceVariant
        textColor: Color.mOnSurfaceVariant
        onClicked: {
          var snippet = MonitorService.generateConfigSnippet();
          if (snippet) {
            Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]);
            ToastService.showNotice("Configuração Copiada", "TOML salvo na área de transferência!", "copy");
          }
        }
      }
    }
  }
}
