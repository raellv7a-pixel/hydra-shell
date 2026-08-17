// SPDX-License-Identifier: GPL-3.0-only

import Hydra.Visual

import QtQuick
import QtQuick.Layouts
import Quickshell

ShellRoot {
  FloatingWindow {
    id: smokeWindow

    visible: true
    title: "Hydra Visual — teste de blobs"
    implicitWidth: 960
    implicitHeight: 620
    minimumSize: Qt.size(760, 520)
    color: "#111018"

    Shortcut {
      sequence: "Escape"
      onActivated: Qt.quit()
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 32
      spacing: 20

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
          text: "Hydra.Visual"
          color: "#f4efff"
          font.pixelSize: 28
          font.weight: Font.DemiBold
        }

        Text {
          text: "Fusão SDF, raios independentes e deformação por velocidade"
          color: "#b9b1c8"
          font.pixelSize: 15
        }
      }

      Rectangle {
        id: stage

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 28
        color: "#1b1925"
        border.color: "#343044"
        border.width: 1
        clip: false

        BlobGroup {
          id: blobGroup

          color: "#a995ff"
          smoothing: 38
          cornerFill: false
        }

        BlobRect {
          id: anchorBlob

          group: blobGroup
          x: stage.width * 0.18
          y: stage.height * 0.31
          width: 250
          height: 190
          radius: 52
          topLeftRadius: 84
          topRightRadius: 30
          bottomLeftRadius: 42
          bottomRightRadius: 72
          deformScale: 0.0012
          stiffness: 180
          damping: 18
        }

        BlobRect {
          id: movingBlob

          group: blobGroup
          x: stage.width - width - stage.width * 0.12
          y: stage.height * 0.39
          width: 210
          height: 150
          radius: 44
          topLeftRadius: 24
          topRightRadius: 70
          bottomLeftRadius: 66
          bottomRightRadius: 32
          deformScale: 0.0018
          stiffness: 155
          damping: 15

          SequentialAnimation on x {
            running: true
            loops: Animation.Infinite

            PauseAnimation {
              duration: 650
            }

            NumberAnimation {
              to: anchorBlob.x + anchorBlob.width - 52
              duration: 1350
              easing.type: Easing.InOutCubic
            }

            PauseAnimation {
              duration: 700
            }

            NumberAnimation {
              to: stage.width - movingBlob.width - stage.width * 0.12
              duration: 1500
              easing.type: Easing.OutBack
            }

            PauseAnimation {
              duration: 800
            }
          }
        }

        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.margins: 18
          text: "Esc fecha o teste • o blob móvel deve fundir, separar e voltar ao repouso"
          color: "#aaa2ba"
          font.pixelSize: 13
        }
      }
    }
  }
}
