import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
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
  readonly property var sceneBounds: computeSceneBounds(outputs)
  // Scale is computed against the scroll viewport (fixed), not the canvas
  // itself — the canvas is free to grow past the viewport (see
  // computeRequiredSceneSize below) when the 90x55 minimum tile size would
  // otherwise force a monitor tile outside the visible area. That overflow
  // becomes scrollable instead of silently clipped.
  readonly property real viewportWidth: sceneScrollWrapper ? sceneScrollWrapper.availableWidth : 0
  readonly property real sceneScale: computeSceneScale()
  readonly property var requiredSceneSize: computeRequiredSceneSize()

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
    var minX = list[0].x;
    var minY = list[0].y;
    var maxX = list[0].x + (list[0].logicalWidth || list[0].width);
    var maxY = list[0].y + (list[0].logicalHeight || list[0].height);

    for (var i = 1; i < list.length; i++) {
      var output = list[i];
      minX = Math.min(minX, output.x);
      minY = Math.min(minY, output.y);
      maxX = Math.max(maxX, output.x + (output.logicalWidth || output.width));
      maxY = Math.max(maxY, output.y + (output.logicalHeight || output.height));
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

  // How much of the box the current arrangement should occupy. Too high and
  // the tiles touch the edges with nowhere to drag them; too low and they
  // shrink into a small cluster adrift in empty space. 0.72 keeps the tiles
  // comfortably large while leaving a usable margin to rearrange into.
  readonly property real sceneFitFraction: 0.72

  // The box height follows the arrangement's own aspect ratio instead of
  // being a fixed strip: side-by-side monitors get a shorter box, stacked
  // ones a taller box, so the tiles and the box always stay proportionate
  // to each other. Clamped so it never collapses or dominates the tab.
  readonly property real viewportHeight: {
    var usableWidth = (root.viewportWidth - scenePadding * 2) * sceneFitFraction;
    if (usableWidth <= 0)
      return 280;
    // Height the arrangement would take once scaled to that usable width,
    // then grossed back up by the same fraction to re-add the drag margin.
    var arrangementHeight = usableWidth * (sceneBounds.height / sceneBounds.width);
    return Math.max(280, Math.min(560, arrangementHeight / sceneFitFraction + scenePadding * 2));
  }

  // Centers the arrangement in the box. Without this the tiles anchor to the
  // top-left corner and all the slack piles up on the right/bottom, which
  // reads as wasted space rather than room to drag into.
  readonly property real sceneOffsetX: Math.max(scenePadding, (root.viewportWidth - sceneBounds.width * sceneScale) / 2)
  readonly property real sceneOffsetY: Math.max(scenePadding, (root.viewportHeight - sceneBounds.height * sceneScale) / 2)

  function computeSceneScale() {
    var availableWidth = (root.viewportWidth - (scenePadding * 2)) * sceneFitFraction;
    var availableHeight = (root.viewportHeight - (scenePadding * 2)) * sceneFitFraction;
    if (availableWidth <= 0 || availableHeight <= 0)
      return 1;
    return Math.max(0.02, Math.min(availableWidth / sceneBounds.width, availableHeight / sceneBounds.height));
  }

  // The canvas must be at least as big as every tile actually needs once the
  // 90x55 minimum tile size (applied in the delegate below) is accounted
  // for — otherwise a tile can extend past a canvas sized only for the
  // "ideal" scaled bounds. Falls back to the viewport size when everything
  // fits naturally, so the common case never scrolls.
  function computeRequiredSceneSize() {
    var maxX = root.viewportWidth;
    var maxY = root.viewportHeight;
    for (var i = 0; i < outputs.length; i++) {
      var output = outputs[i];
      var tileRight = layoutToCanvasX(output.x) + Math.max(90, (output.logicalWidth || output.width) * sceneScale);
      var tileBottom = layoutToCanvasY(output.y) + Math.max(55, (output.logicalHeight || output.height) * sceneScale);
      maxX = Math.max(maxX, tileRight + scenePadding);
      maxY = Math.max(maxY, tileBottom + scenePadding);
    }
    return {
      "width": maxX,
      "height": maxY
    };
  }

  function layoutToCanvasX(val) {
    return sceneOffsetX + ((val - sceneBounds.minX) * sceneScale);
  }
  function layoutToCanvasY(val) {
    return sceneOffsetY + ((val - sceneBounds.minY) * sceneScale);
  }
  function canvasToLayoutX(val) {
    return sceneBounds.minX + ((val - sceneOffsetX) / sceneScale);
  }
  function canvasToLayoutY(val) {
    return sceneBounds.minY + ((val - sceneOffsetY) / sceneScale);
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
        var hz = Number(m.refresh || 0).toFixed(0);
        var label = m.width + "x" + m.height + (hz > 0 ? ("@" + hz + "Hz") : "");
        model.push({
                     key: m.id || label,
                     name: label
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
    spacing: Style.marginL

    // ----------------------------------------------------
    // 1. VISUAL DRAG-AND-DROP CANVAS (FULL WIDTH AT TOP)
    // ----------------------------------------------------
    NText {
      text: "Arranjo Físico de Monitores"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    // Scrollable so a tile forced to its 90x55 minimum size (see
    // computeRequiredSceneSize) can overflow the viewport without being
    // silently clipped — the common 2-monitor case fits and never scrolls.
    NScrollView {
      id: sceneScrollWrapper
      Layout.fillWidth: true
      Layout.preferredHeight: root.viewportHeight
      horizontalPolicy: ScrollBar.AsNeeded
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false

      Rectangle {
        id: sceneCanvas
        width: Math.max(sceneScrollWrapper.availableWidth, root.requiredSceneSize.width)
        height: Math.max(root.viewportHeight, root.requiredSceneSize.height)
        color: Qt.alpha(Color.mSurface, 0.8)
        border.color: Color.mOutline
        border.width: Style.borderS
        radius: Style.radiusL
        clip: true

        // Grid lines overlay
        Canvas {
          anchors.fill: parent
          opacity: 0.15
          onPaint: {
            var ctx = getContext("2d");
            ctx.strokeStyle = Color.mOutline;
            ctx.lineWidth = 1;
            for (var x = 0; x < width; x += 40) {
              ctx.beginPath();
              ctx.moveTo(x, 0);
              ctx.lineTo(x, height);
              ctx.stroke();
            }
            for (var y = 0; y < height; y += 40) {
              ctx.beginPath();
              ctx.moveTo(0, y);
              ctx.lineTo(width, y);
              ctx.stroke();
            }
          }
        }

        Repeater {
          model: root.outputs

          delegate: Rectangle {
            id: monitorTile
            readonly property var output: modelData
            readonly property bool isSelected: output.outputId === root.selectedOutputId

            x: root.layoutToCanvasX(output.x)
            y: root.layoutToCanvasY(output.y)
            width: Math.max(90, (output.logicalWidth || output.width) * root.sceneScale)
            height: Math.max(55, (output.logicalHeight || output.height) * root.sceneScale)

            color: isSelected ? Qt.alpha(Color.mPrimary, 0.28) : Qt.alpha(Color.mSurfaceVariant, 0.65)
            border.color: isSelected ? Color.mPrimary : Color.mOutline
            border.width: isSelected ? 2 : 1
            radius: Style.radiusM

            Behavior on x {
              enabled: !dragArea.drag.active
              NumberAnimation {
                duration: 120
              }
            }
            Behavior on y {
              enabled: !dragArea.drag.active
              NumberAnimation {
                duration: 120
              }
            }

            MouseArea {
              id: dragArea
              anchors.fill: parent
              // Without this, the NScrollView wrapping sceneCanvas (added to
              // fix clipping) steals the mouse grab via Flickable's
              // childMouseEventFilter as soon as the drag threshold is
              // crossed, so drag.target never actually moves.
              preventStealing: true
              drag.target: parent
              drag.axis: Drag.XAndYAxis
              drag.minimumX: root.scenePadding
              drag.minimumY: root.scenePadding
              drag.maximumX: sceneCanvas.width - monitorTile.width - root.scenePadding
              drag.maximumY: sceneCanvas.height - monitorTile.height - root.scenePadding

              onPressed: MonitorService.selectOutput(output.outputId)
              // Committing on every onPositionChanged (every mouse-move frame
              // during the drag) was the real cause of the reported lag: each
              // call deep-clones the whole output list and reassigns
              // draftOutputs, which cascades into recomputing sceneBounds/
              // sceneScale and re-laying-out every tile — dozens of times a
              // second. drag.target already moves this tile smoothly on its
              // own; only sync the data model once, when the drag ends.
              onReleased: {
                var newX = root.canvasToLayoutX(monitorTile.x);
                var newY = root.canvasToLayoutY(monitorTile.y);
                MonitorService.updateOutputPosition(output.outputId, newX, newY);
              }
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

      NComboBox {
        Layout.fillWidth: true
        label: "Espelhar Tela (Mirror)"
        description: "Espelha o conteúdo exibido em outro monitor"
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
        Layout.fillWidth: true
        label: "Resolução & Taxa de Atualização"
        description: "Selecione a resolução e frequência de atualização (Hz) do monitor selecionado"
        model: root.resolutionModel(root.selectedOutput)
        currentKey: root.selectedOutput ? (root.selectedOutput.modeId || (root.selectedOutput.width + "x" + root.selectedOutput.height + "@" + Math.round(root.selectedOutput.refresh) + "Hz")) : ""
        onSelected: key => {
          if (root.selectedOutput) {
            var parts = key.split("@");
            if (parts.length === 2) {
              var wh = parts[0].split("x");
              var w = parseInt(wh[0]) || root.selectedOutput.width;
              var h = parseInt(wh[1]) || root.selectedOutput.height;
              var hz = parseFloat(parts[1].replace("Hz", "")) || root.selectedOutput.refresh;
              MonitorService.updateOutput(root.selectedOutput.outputId, {
                                            "width": w,
                                            "height": h,
                                            "refresh": hz
                                          });
            }
          }
        }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: "Escala do Monitor"
        description: "Ajusta o fator de escala (DPI) para elementos e fontes nesta tela"
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
        enabled: !MonitorService.isBusy
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
        onClicked: MonitorService.fetchOutputs()
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
      text: "Sintaxe Lua (Hyprland 0.55+ em ~/.config/hypr/lua/monitors.lua):"
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
