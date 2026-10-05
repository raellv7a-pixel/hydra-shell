import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.System

NScrollView {
  id: root

  SetupShortcuts {
    id: shortcuts
  }

  // Capability checks for Screen Toolkit
  property bool ocrSupported: false
  property bool qrSupported: false

  Process {
    id: checkCaps
    command: ["sh", "-c", "which tesseract >/dev/null 2>&1 && echo ocr; which zbarimg >/dev/null 2>&1 && echo qr"]
    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text || "";
        root.ocrSupported = text.includes("ocr");
        root.qrSupported = text.includes("qr");
      }
    }
  }

  Component.onCompleted: {
    checkCaps.running = true;
  }

  property int activeHighlight: 0

  readonly property var highlights: [
    {
      id: "launcher",
      titleKey: "setup.hydra.discover.launcher-title",
      descKey: "setup.hydra.discover.launcher-desc",
      chord: shortcuts.launcherChord,
      icon: "rocket"
    },
    {
      id: "dashboard",
      titleKey: "setup.hydra.discover.dashboard-title",
      descKey: "setup.hydra.discover.dashboard-desc",
      chord: shortcuts.dashboardChord,
      icon: "layout-dashboard"
    },
    {
      id: "overview",
      titleKey: "setup.hydra.discover.overview-title",
      descKey: "setup.hydra.discover.overview-desc",
      chord: shortcuts.overviewChord,
      icon: "layout-grid"
    },
    {
      id: "toolkit",
      titleKey: "setup.hydra.discover.toolkit-title",
      descKey: "setup.hydra.discover.toolkit-desc",
      chord: shortcuts.toolkitChord,
      icon: "camera"
    }
  ]

  horizontalPolicy: ScrollBar.AlwaysOff
  verticalPolicy: ScrollBar.AlwaysOff

  ColumnLayout {
    width: root.availableWidth
    spacing: Style.marginXL

    NText {
      text: I18n.tr("setup.hydra.discover.header")
      pointSize: Style.fontSizeXXXL
      font.weight: Style.fontWeightBold
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }

    NText {
      text: I18n.tr("setup.hydra.discover.subheader")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeM
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }

    // Mini desktop canvas simulation
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: 260
      color: Color.mSurfaceContainerLowest

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.marginM
        radius: Style.radiusM
        color: Color.mSurfaceContainer
        border.color: Color.mOutline
        border.width: Style.borderS
        clip: true

        // Top Frame Bar simulation
        Rectangle {
          id: simBar
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 28
          color: Color.mSurfaceContainerHigh

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM

            NIcon {
              icon: "sparkles"
              pointSize: Style.fontSizeS
              color: Color.mPrimary
            }

            NText {
              text: "Hydra"
              pointSize: Style.fontSizeXS
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            NText {
              text: "12:00"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            Item { Layout.fillWidth: true }

            RowLayout {
              spacing: 6
              NIcon { icon: "wifi"; pointSize: 10; color: Color.mOnSurfaceVariant }
              NIcon { icon: "volume"; pointSize: 10; color: Color.mOnSurfaceVariant }
              NIcon { icon: "battery"; pointSize: 10; color: Color.mOnSurfaceVariant }
            }
          }
        }

        // Mock Desktop Work area with highlighted element
        Item {
          anchors.top: simBar.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          // 1. Launcher Mock Surface (Bottom Center)
          Rectangle {
            visible: root.activeHighlight === 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.marginM
            width: 220
            height: 120
            radius: Style.radiusM
            color: Color.mSurfaceContainerHigh
            border.color: Color.mPrimary
            border.width: Style.borderM

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: 6

              Rectangle {
                Layout.fillWidth: true
                height: 22
                radius: Style.radiusS
                color: Color.mSurfaceContainerHighest
                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 6
                  NIcon { icon: "search"; pointSize: 10; color: Color.mPrimary }
                  NText { text: I18n.tr("setup.hydra.discover.mock-search"); pointSize: 9; color: Color.mOnSurfaceVariant }
                }
              }

              RowLayout {
                spacing: 8
                Repeater {
                  model: 4
                  delegate: Rectangle {
                    width: 28
                    height: 28
                    radius: Style.radiusS
                    color: Color.mSurfaceContainerHighest
                    NIcon { anchors.centerIn: parent; icon: ["terminal", "folder", "browser", "music"][index]; pointSize: 12; color: Color.mPrimary }
                  }
                }
              }
            }
          }

          // 2. Dashboard Mock Surface (Top Center / Right attached to bar)
          Rectangle {
            visible: root.activeHighlight === 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 2
            width: 200
            height: 130
            radius: Style.radiusM
            color: Color.mSurfaceContainerHigh
            border.color: Color.mPrimary
            border.width: Style.borderM

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: 6

              NText {
                text: I18n.tr("setup.hydra.discover.mock-dashboard")
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightBold
                color: Color.mPrimary
              }

              RowLayout {
                spacing: 6
                Rectangle {
                  width: 50
                  height: 32
                  radius: Style.radiusS
                  color: Color.mPrimaryContainer
                  NText { anchors.centerIn: parent; text: "Wi-Fi"; pointSize: 8; color: Color.mOnPrimaryContainer; font.weight: Style.fontWeightBold }
                }
                Rectangle {
                  width: 50
                  height: 32
                  radius: Style.radiusS
                  color: Color.mSurfaceContainerHighest
                  NText { anchors.centerIn: parent; text: "BT"; pointSize: 8; color: Color.mOnSurfaceVariant }
                }
                Rectangle {
                  width: 50
                  height: 32
                  radius: Style.radiusS
                  color: Color.mSurfaceContainerHighest
                  NText { anchors.centerIn: parent; text: "DND"; pointSize: 8; color: Color.mOnSurfaceVariant }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 14
                radius: 7
                color: Color.mSurfaceContainerHighest
                Rectangle {
                  width: parent.width * 0.7
                  height: parent.height
                  radius: 7
                  color: Color.mPrimary
                }
              }
            }
          }

          // 3. Overview Mock Surface (Workspace cards grid)
          Item {
            visible: root.activeHighlight === 2
            anchors.fill: parent
            anchors.margins: Style.marginL

            RowLayout {
              anchors.centerIn: parent
              spacing: 12

              Repeater {
                model: 3
                delegate: Rectangle {
                  width: 70
                  height: 50
                  radius: Style.radiusS
                  color: index === 0 ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh
                  border.color: index === 0 ? Color.mPrimary : Color.mOutline
                  border.width: index === 0 ? Style.borderM : Style.borderS

                  NText {
                    anchors.centerIn: parent
                    text: (index + 1).toString()
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeS
                    color: index === 0 ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
                  }
                }
              }
            }
          }

          // 4. Screen Toolkit Mock Surface (Floating annotation / capture pill)
          Item {
            visible: root.activeHighlight === 3
            anchors.fill: parent

            // Mock selection border
            Rectangle {
              anchors.centerIn: parent
              width: 140
              height: 80
              color: Qt.alpha(Color.mPrimary, 0.15)
              border.color: Color.mPrimary
              border.width: 1
            }

            // Mock toolkit floating bar
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.marginM
              width: 160
              height: 32
              radius: 16
              color: Color.mSurfaceContainerHighest
              border.color: Color.mPrimary
              border.width: Style.borderS

              RowLayout {
                anchors.centerIn: parent
                spacing: 8
                NIcon { icon: "crop"; pointSize: 12; color: Color.mPrimary }
                NIcon { icon: "pencil"; pointSize: 12; color: Color.mOnSurface }
                NIcon { icon: "file-text"; pointSize: 12; color: root.ocrSupported ? Color.mOnSurface : Color.mOutline }
                NIcon { icon: "qrcode"; pointSize: 12; color: root.qrSupported ? Color.mOnSurface : Color.mOutline }
                NIcon { icon: "check"; pointSize: 12; color: Color.mPrimary }
              }
            }
          }
        }
      }
    }

    // 4 Highlights Cards Grid with keyboard accessibility
    GridLayout {
      Layout.fillWidth: true
      columns: 2
      rowSpacing: Style.marginM
      columnSpacing: Style.marginM

      Repeater {
        model: root.highlights
        delegate: NBox {
          id: highlightCard
          required property int index
          required property var modelData

          Layout.fillWidth: true
          implicitHeight: cardLayout.implicitHeight + Style.marginM * 2
          color: root.activeHighlight === index ? Color.mPrimaryContainer : Color.mSurfaceContainer
          border.color: highlightCard.activeFocus || root.activeHighlight === index ? Color.mPrimary : "transparent"
          border.width: highlightCard.activeFocus ? Style.borderL : root.activeHighlight === index ? Style.borderM : 0

          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: I18n.tr(modelData.titleKey)

          Keys.onSpacePressed: event => { root.activeHighlight = index; event.accepted = true; }
          Keys.onReturnPressed: event => { root.activeHighlight = index; event.accepted = true; }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              highlightCard.forceActiveFocus();
              root.activeHighlight = index;
            }
          }

          RowLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: modelData.icon
              pointSize: Style.fontSizeXL
              color: root.activeHighlight === index ? Color.mOnPrimaryContainer : Color.mPrimary
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              NText {
                text: I18n.tr(modelData.titleKey)
                font.weight: Style.fontWeightBold
                color: root.activeHighlight === index ? Color.mOnPrimaryContainer : Color.mOnSurface
              }

              NText {
                text: {
                  if (modelData.id === "toolkit") {
                    let desc = I18n.tr(modelData.descKey);
                    if (root.ocrSupported && root.qrSupported) {
                      desc += " (" + I18n.tr("setup.hydra.discover.toolkit-caps-both") + ")";
                    } else if (root.ocrSupported) {
                      desc += " (" + I18n.tr("setup.hydra.discover.toolkit-caps-ocr") + ")";
                    } else if (root.qrSupported) {
                      desc += " (" + I18n.tr("setup.hydra.discover.toolkit-caps-qr") + ")";
                    }
                    return desc;
                  }
                  return I18n.tr(modelData.descKey);
                }
                color: root.activeHighlight === index ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }
            }

            Rectangle {
              height: 28
              radius: Style.radiusS
              color: root.activeHighlight === index ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHigh
              border.color: Color.mOutline
              border.width: Style.borderS
              implicitWidth: chordBadge.implicitWidth + Style.marginM * 2

              NText {
                id: chordBadge
                anchors.centerIn: parent
                text: modelData.chord
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeS
                color: Color.mPrimary
              }
            }
          }
        }
      }
    }
  }
}
