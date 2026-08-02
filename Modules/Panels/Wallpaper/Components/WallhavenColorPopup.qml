import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Popup {
  id: root

  width: 250
  height: 200
  padding: Style.marginM
  modal: true
  dim: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  signal colorSelected(string colorHex)

  function showAt(item) {
    if (item) {
      var localPos = item.mapToItem(parent, 0, item.height + Style.marginS);
      x = localPos.x - width + item.width; // align right
      y = localPos.y;
    }
    open();
  }

  background: Rectangle {
    id: bgRect
    color: Color.mSurface
    radius: Style.radiusM
    border.color: Color.mOutline
    border.width: Style.borderS
    NDropShadow { source: bgRect }
  }

  contentItem: ColumnLayout {
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      NText {
        text: "Cor Predominante"
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
      }
      NIconButton {
        icon: "eraser"
        tooltipText: "Limpar Cor"
        baseSize: Style.baseWidgetSize * 0.7
        visible: Settings.data.wallpaper.wallhavenColors !== ""
        onClicked: {
          root.colorSelected("");
          root.close();
        }
      }
    }

    Flow {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginXS
      
      Repeater {
        model: [
          "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399",
          "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900",
          "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300",
          "000000", "999999", "cccccc", "ffffff", "424153"
        ]
        
        Rectangle {
          width: 24
          height: 24
          radius: 12
          color: "#" + modelData
          border.color: Color.mOutline
          border.width: Settings.data.wallpaper.wallhavenColors === modelData ? 2 : 1
          
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.colorSelected(modelData);
              root.close();
            }
          }
          
          // Selection Indicator
          NIcon {
            anchors.centerIn: parent
            icon: "check"
            pointSize: 14
            color: (modelData === "ffffff" || modelData === "cccccc") ? "#000000" : "#ffffff"
            visible: Settings.data.wallpaper.wallhavenColors === modelData
          }
        }
      }
    }
  }
}
