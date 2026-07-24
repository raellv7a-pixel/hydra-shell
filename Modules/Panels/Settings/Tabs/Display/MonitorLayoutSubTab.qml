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
  implicitHeight: Math.max(520, contentRow.implicitHeight + actionRow.implicitHeight + Style.marginL * 3)

  readonly property var outputs: MonitorService.draftOutputs
  readonly property var selectedOutput: MonitorService.getSelectedOutput()

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
      text: "Copiar Configuração do Hyprland"
      icon: "copy"
      backgroundColor: Color.mSurfaceVariant
      textColor: Color.mOnSurfaceVariant
      onClicked: {
        var snippet = MonitorService.generateConfigSnippet();
        if (snippet) {
          Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]);
          ToastService.showNotice("Configuração Copiada", "Linhas do hyprland.conf copiadas para a área de transferência!", "copy");
        }
      }
    }

    Item { Layout.fillWidth: true } // Spacer

    NButton {
      text: "Restaurar Padrão"
      icon: "refresh"
      backgroundColor: Color.mSurfaceVariant
      textColor: Color.mOnSurfaceVariant
      onClicked: MonitorService.fetchOutputs()
    }
  }

  RowLayout {
    id: contentRow
    Layout.fillWidth: true
    Layout.preferredHeight: 440
    spacing: Style.marginL

    // Visual Monitor Arrangement Canvas
    Rectangle {
      id: sceneCanvas
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Qt.alpha(Color.mSurface, 0.8)
      border.color: Color.mOutline
      border.width: Style.borderS
      radius: Style.radiusL
      clip: true

      Repeater {
        model: root.outputs

        delegate: Rectangle {
          id: monitorTile
          readonly property var output: modelData
          readonly property bool isSelected: output.outputId === root.selectedOutputId

          x: root.layoutToCanvasX(output.x)
          y: root.layoutToCanvasY(output.y)
          width: Math.max(80, (output.logicalWidth || output.width) * root.sceneScale)
          height: Math.max(50, (output.logicalHeight || output.height) * root.sceneScale)

          color: isSelected ? Qt.alpha(Color.mPrimary, 0.25) : Qt.alpha(Color.mSurfaceVariant, 0.6)
          border.color: isSelected ? Color.mPrimary : Color.mOutline
          border.width: isSelected ? 2 : 1
          radius: Style.radiusM

          Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: 150 } }
          Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: 150 } }

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

    // Right Side Monitor Inspector Panel
    Rectangle {
      Layout.preferredWidth: 320
      Layout.fillHeight: true
      color: Qt.alpha(Color.mSurface, 0.6)
      border.color: Color.mOutline
      border.width: Style.borderS
      radius: Style.radiusL

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
        visible: root.selectedOutput !== null

        NText {
          text: root.selectedOutput ? (root.selectedOutput.name + " (" + (root.selectedOutput.model || root.selectedOutput.make || "Monitor") + ")") : "Nenhum monitor selecionado"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }

        NValueSlider {
          Layout.fillWidth: true
          label: "Escala do Monitor"
          from: 0.8
          to: 2.0
          stepSize: 0.1
          value: root.selectedOutput ? (root.selectedOutput.scale || 1.0) : 1.0
          onMoved: val => {
            if (root.selectedOutput) {
              MonitorService.updateOutput(root.selectedOutput.outputId, { "scale": Math.round(val * 10) / 10 });
            }
          }
        }

        NComboBox {
          Layout.fillWidth: true
          label: "Orientação / Rotação"
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

        NValueSlider {
          Layout.fillWidth: true
          label: "Posição X (px)"
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
          label: "Posição Y (px)"
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

        Item { Layout.fillHeight: true }
      }
    }
  }
}
