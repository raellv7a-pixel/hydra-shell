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
  implicitHeight: Math.max(540, contentRow.implicitHeight + subTabBar.implicitHeight + actionRow.implicitHeight + Style.marginL * 3)

  readonly property var outputs: MonitorService.draftOutputs
  readonly property var selectedOutput: MonitorService.getSelectedOutput()
  property int activeSubTab: 0

  property real scenePadding: 24 * Style.uiScaleRatio
  readonly property var sceneBounds: computeSceneBounds(outputs)
  readonly property real sceneScale: computeSceneScale()

  function computeSceneBounds(list) {
    if (!list || list.length === 0) {
      return { "minX": 0, "minY": 0, "maxX": 1920, "maxY": 1080, "width": 1920, "height": 1080 };
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
      "minX": minX, "minY": minY, "maxX": maxX, "maxY": maxY,
      "width": Math.max(1, maxX - minX), "height": Math.max(1, maxY - minY)
    };
  }

  function computeSceneScale() {
    var availableWidth = sceneCanvas.width - (scenePadding * 2);
    var availableHeight = sceneCanvas.height - (scenePadding * 2);
    if (availableWidth <= 0 || availableHeight <= 0) return 1;
    return Math.max(0.02, Math.min(availableWidth / sceneBounds.width, availableHeight / sceneBounds.height));
  }

  function layoutToCanvasX(val) { return scenePadding + ((val - sceneBounds.minX) * sceneScale); }
  function layoutToCanvasY(val) { return scenePadding + ((val - sceneBounds.minY) * sceneScale); }
  function canvasToLayoutX(val) { return sceneBounds.minX + ((val - scenePadding) / sceneScale); }
  function canvasToLayoutY(val) { return sceneBounds.minY + ((val - scenePadding) / sceneScale); }

  function resolutionModel(output) {
    if (!output || !output.availableModes) return [];
    var model = [];
    var modes = output.availableModes;
    for (var i = 0; i < modes.length; i++) {
      var m = modes[i];
      if (typeof m === "string") {
        model.push({ key: m, name: m });
      } else if (typeof m === "object") {
        var hz = Number(m.refresh || 0).toFixed(0);
        var label = m.width + "x" + m.height + (hz > 0 ? ("@" + hz + "Hz") : "");
        model.push({ key: m.id || label, name: label });
      }
    }
    return model;
  }

  // Navigation Sub-Bar
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
  // TAB 0: ARRANJO VISUAL DAS TELAS
  // ==========================================
  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: root.activeSubTab === 0
    spacing: Style.marginM

    RowLayout {
      id: contentRow
      Layout.fillWidth: true
      Layout.preferredHeight: 400
      spacing: Style.marginL

      // Visual Monitor Canvas
      Rectangle {
        id: sceneCanvas
        Layout.fillWidth: true
        Layout.fillHeight: true
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
              ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
            }
            for (var y = 0; y < height; y += 40) {
              ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
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

            Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: 120 } }
            Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: 120 } }

            MouseArea {
              id: dragArea
              anchors.fill: parent
              drag.target: parent
              drag.axis: Drag.XAndYAxis
              drag.minimumX: root.scenePadding
              drag.minimumY: root.scenePadding
              drag.maximumX: sceneCanvas.width - monitorTile.width - root.scenePadding
              drag.maximumY: sceneCanvas.height - monitorTile.height - root.scenePadding

              onPressed: MonitorService.selectOutput(output.outputId)
              onPositionChanged: {
                if (drag.active) {
                  var newX = root.canvasToLayoutX(monitorTile.x);
                  var newY = root.canvasToLayoutY(monitorTile.y);
                  MonitorService.updateOutputPosition(output.outputId, newX, newY);
                }
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
                anchors.horizontalCenter: parent.horizontalCenter
              }

              NText {
                text: output.width + "x" + output.height + (output.refresh ? ("@" + Math.round(output.refresh) + "Hz") : "")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }
        }
      }

      // Right Side Inspector (Width: 340px)
      Rectangle {
        Layout.preferredWidth: 340
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.6)
        border.color: Color.mOutline
        border.width: Style.borderS
        radius: Style.radiusL

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.marginM
          clip: true

          ColumnLayout {
            width: parent.width - Style.marginS
            spacing: Style.marginM
            visible: root.selectedOutput !== null

            NText {
              text: root.selectedOutput ? (root.selectedOutput.name + " (" + (root.selectedOutput.model || root.selectedOutput.make || "Monitor") + ")") : "Nenhum monitor"
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NText {
              text: "Resolução & Frequência"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NComboBox {
              Layout.fillWidth: true
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
                    MonitorService.updateOutput(root.selectedOutput.outputId, { "width": w, "height": h, "refresh": hz });
                  }
                }
              }
            }

            NText {
              text: "Escala do Monitor"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NValueSlider {
              Layout.fillWidth: true
              from: 0.8
              to: 2.0
              stepSize: 0.05
              value: root.selectedOutput ? (root.selectedOutput.scale || 1.0) : 1.0
              onMoved: val => {
                if (root.selectedOutput) {
                  MonitorService.updateOutput(root.selectedOutput.outputId, { "scale": Math.round(val * 100) / 100 });
                }
              }
            }

            NText {
              text: "Orientação / Rotação"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NComboBox {
              Layout.fillWidth: true
              currentKey: String(root.selectedOutput ? (root.selectedOutput.transform || 0) : 0)
              model: [
                { key: "0", name: "Normal (0°)" },
                { key: "1", name: "90° Rotação" },
                { key: "2", name: "180° Invertido" },
                { key: "3", name: "270° Rotação" }
              ]
              onSelected: key => {
                if (root.selectedOutput) {
                  MonitorService.updateOutput(root.selectedOutput.outputId, { "transform": parseInt(key) });
                }
              }
            }

            NText {
              text: "Posição Manual (X, Y)"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NTextInput {
                Layout.fillWidth: true
                label: "X"
                text: String(root.selectedOutput ? Math.round(root.selectedOutput.x) : 0)
                onEditingFinished: {
                  if (root.selectedOutput) {
                    MonitorService.updateOutputPosition(root.selectedOutput.outputId, parseInt(text) || 0, root.selectedOutput.y);
                  }
                }
              }

              NTextInput {
                Layout.fillWidth: true
                label: "Y"
                text: String(root.selectedOutput ? Math.round(root.selectedOutput.y) : 0)
                onEditingFinished: {
                  if (root.selectedOutput) {
                    MonitorService.updateOutputPosition(root.selectedOutput.outputId, root.selectedOutput.x, parseInt(text) || 0);
                  }
                }
              }
            }
          }
        }
      }
    }

    // Action Bar at Bottom
    RowLayout {
      id: actionRow
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        text: "Aplicar Layout"
        icon: "check"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: !MonitorService.isBusy
        onClicked: MonitorService.applyLayout()
      }

      NButton {
        text: "Restaurar Padrão"
        icon: "refresh"
        backgroundColor: Color.mSurfaceVariant
        textColor: Color.mOnSurfaceVariant
        onClicked: MonitorService.fetchOutputs()
      }

      Item { Layout.fillWidth: true } // Spacer
    }
  }

  // ==========================================
  // TAB 1: CONFIGURAÇÃO DO HYPRLAND
  // ==========================================
  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: root.activeSubTab === 1
    spacing: Style.marginM

    NText {
      text: "Linhas para o seu hyprland.conf"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    NText {
      text: "Copie as linhas abaixo para salvar o layout de monitores permanentemente no seu arquivo ~/.config/hypr/hyprland.conf:"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 180
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
          text: MonitorService.generateConfigSnippet() || "monitor=DP-1,1920x1080@180,0x0,1.0\nmonitor=DP-2,1920x1080@165,-1920x0,1.0"
          font.family: "monospace"
          pointSize: Style.fontSizeS
          color: Color.mPrimary
        }
      }
    }

    NButton {
      text: "Copiar Linhas de Configuração"
      icon: "copy"
      backgroundColor: Color.mPrimary
      textColor: Color.mOnPrimary
      onClicked: {
        var snippet = MonitorService.generateConfigSnippet();
        if (snippet) {
          Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]);
          ToastService.showNotice("Configuração Copiada", "Linhas de monitor salvas na área de transferência!", "copy");
        }
      }
    }
  }
}
