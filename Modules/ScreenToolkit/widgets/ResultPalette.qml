import QtQuick
import Quickshell.Io
import "../utils/utils.js" as U
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property var mainInstance: null
  implicitWidth: parent?.width ?? 0
  implicitHeight: contentCol.implicitHeight
  readonly property var paletteColors: mainInstance?.paletteColors ?? []
  Process {
    id: clipProc
  }
  function _copy(text) {
    if (!text || text === "")
      return;
    clipProc.exec({
                    command: ["bash", "-c", "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"]
                  });
  }
  function clear() {
    if (mainInstance) {
      mainInstance.clearPaletteResult();
      mainInstance.activeTool = "";
    }
  }
  Column {
    id: contentCol
    width: parent.width
    spacing: Style.spaceM
    Rectangle {
      visible: root.paletteColors.length === 0
      width: parent.width
      height: 36
      radius: Style.radiusCard
      color: emptyPalBtn.containsMouse ? Color.mPrimary : Color.mSurface
      border.color: Color.mPrimary
      border.width: Style.capsuleBorderWidth
      Row {
        anchors.centerIn: parent
        spacing: Style.spaceS
        NIcon {
          icon: "palette"
          color: emptyPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
        }
        NText {
          text: pluginApi?.tr("panel.pickAgain")
          color: emptyPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
          pointSize: Style.fontSizeLabelMedium
        }
      }
      MouseArea {
        id: emptyPalBtn
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mainInstance?.runPalette()
      }
      NStateLayer {
        anchors.fill: parent
        hovered: emptyPalBtn.containsMouse
        pressed: emptyPalBtn.pressed
        stateColor: Color.mPrimary
      }
    }
    Column {
      visible: root.paletteColors.length > 0
      width: parent.width
      spacing: Style.spaceM
      Rectangle {
        width: parent.width
        height: 36
        radius: Style.radiusCard
        color: pickAgainPalBtn.containsMouse ? Color.mPrimary : Color.mSurface
        border.color: Color.mPrimary
        border.width: Style.capsuleBorderWidth
        Row {
          anchors.centerIn: parent
          spacing: Style.spaceS
          NIcon {
            icon: "palette"
            color: pickAgainPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
          }
          NText {
            text: pluginApi?.tr("panel.pickAgain")
            color: pickAgainPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
            pointSize: Style.fontSizeLabelMedium
          }
        }
        MouseArea {
          id: pickAgainPalBtn
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: mainInstance?.runPalette()
        }
        NStateLayer {
          anchors.fill: parent
          hovered: pickAgainPalBtn.containsMouse
          pressed: pickAgainPalBtn.pressed
          stateColor: Color.mPrimary
        }
      }
      Flow {
        width: parent.width
        spacing: Style.spaceS
        Repeater {
          model: root.paletteColors
          delegate: Rectangle {
            width: (root.width - Style.spaceS * 2) / 3 - Style.spaceS
            height: width * 0.7
            radius: Style.radiusCard
            color: modelData
            border.color: swatchBtn.containsMouse ? Color.mPrimary : Style.capsuleBorderColor
            border.width: swatchBtn.containsMouse ? 2 : Style.capsuleBorderWidth
            NText {
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.spaceXS
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.toUpperCase()
              pointSize: Style.fontSizeLabelSmall
              color: "white"
              style: Text.Outline
              styleColor: "#00000066"
            }
            MouseArea {
              id: swatchBtn
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root._copy(modelData);
                ToastService.showNotice(pluginApi?.tr("panel.colorCopied", {
                                                        color: modelData
                                                      }));
              }
              onEntered: TooltipService.show(swatchBtn, modelData.toUpperCase() + " — " + pluginApi?.tr("panel.clickToCopy"))
              onExited: TooltipService.hide()
            }
            NStateLayer {
              anchors.fill: parent
              hovered: swatchBtn.containsMouse
              pressed: swatchBtn.pressed
            }
          }
        }
      }
      Rectangle {
        width: parent.width
        height: 36
        radius: Style.radiusCard
        color: cssBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        Row {
          anchors.centerIn: parent
          spacing: Style.spaceS
          NIcon {
            icon: "copy"
            color: cssBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
          }
          NText {
            text: pluginApi?.tr("palette.cssVars")
            color: cssBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeLabelMedium
          }
        }
        MouseArea {
          id: cssBtn
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var css = root.paletteColors.map(function (c, i) {
              return "--color-" + (i + 1) + ": " + c + ";";
            }).join("\n");
            root._copy(css);
            ToastService.showNotice(pluginApi?.tr("panel.cssVarsCopied"));
          }
        }
        NStateLayer {
          anchors.fill: parent
          hovered: cssBtn.containsMouse
          pressed: cssBtn.pressed
        }
      }
      Rectangle {
        width: parent.width
        height: 36
        radius: Style.radiusCard
        color: hexBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        Row {
          anchors.centerIn: parent
          spacing: Style.spaceS
          NIcon {
            icon: "list"
            color: hexBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
          }
          NText {
            text: pluginApi?.tr("palette.hexList")
            color: hexBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeLabelMedium
          }
        }
        MouseArea {
          id: hexBtn
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root._copy(root.paletteColors.join("\n"));
            ToastService.showNotice(pluginApi?.tr("panel.hexListCopied"));
          }
        }
        NStateLayer {
          anchors.fill: parent
          hovered: hexBtn.containsMouse
          pressed: hexBtn.pressed
        }
      }
      Rectangle {
        width: parent.width
        height: 36
        radius: Style.radiusCard
        color: palClr.containsMouse ? Qt.alpha(Color.mError, 0.15) : Color.mSurface
        border.color: palClr.containsMouse ? Color.mError : Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        Row {
          anchors.centerIn: parent
          spacing: Style.spaceS
          NIcon {
            icon: "trash"
            color: palClr.containsMouse ? Color.mError : Color.mOnSurfaceVariant
          }
          NText {
            text: pluginApi?.tr("panel.clearResult")
            color: palClr.containsMouse ? Color.mError : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeLabelMedium
          }
        }
        MouseArea {
          id: palClr
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.clear()
          onEntered: TooltipService.show(palClr, pluginApi?.tr("panel.clearResult"))
          onExited: TooltipService.hide()
        }
        NStateLayer {
          anchors.fill: parent
          hovered: palClr.containsMouse
          pressed: palClr.pressed
          stateColor: Color.mError
        }
      }
    }
  }
}
