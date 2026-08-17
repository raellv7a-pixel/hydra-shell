import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Popup {
  id: root

  // Swatch geometry scales with the UI so the targets stay clickable on HiDPI.
  readonly property int swatchSize: Math.round(24 * Style.uiScaleRatio)
  readonly property int swatchesPerRow: 8

  width: Math.round((swatchSize + Style.marginXS) * swatchesPerRow + Style.marginM * 2)
  height: Math.round(contentColumn.implicitHeight + Style.marginM * 2)
  padding: Style.marginM
  modal: true
  dim: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  signal colorSelected(string colorHex)

  // Item that had focus before opening, restored on close.
  property Item previousFocusItem: null

  function showAt(item) {
    previousFocusItem = item ?? null;
    if (item) {
      const localPos = item.mapToItem(parent, 0, item.height + Style.marginS);
      x = localPos.x - width + item.width; // align right
      y = localPos.y;
    }
    open();
  }

  onClosed: {
    if (previousFocusItem) {
      previousFocusItem.forceActiveFocus();
      previousFocusItem = null;
    }
  }

  background: Rectangle {
    id: bgRect
    color: Color.mSurface
    radius: Style.radiusM
    border.color: Color.mOutline
    border.width: Style.borderS
    NDropShadow {
      source: bgRect
    }
  }

  contentItem: ColumnLayout {
    id: contentColumn

    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      NText {
        text: I18n.tr("wallpaper.panel.color-filter")
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
        model: ["660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff", "424153"]

        Rectangle {
          required property string modelData

          width: root.swatchSize
          height: root.swatchSize
          radius: width / 2
          color: "#" + modelData
          border.color: Color.mOutline
          border.width: Settings.data.wallpaper.wallhavenColors === modelData ? Style.borderM : Style.borderS

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.colorSelected(parent.modelData);
              root.close();
            }
          }

          // Selection indicator
          NIcon {
            anchors.centerIn: parent
            icon: "check"
            pointSize: Style.fontSizeS
            color: (parent.modelData === "ffffff" || parent.modelData === "cccccc") ? "#000000" : "#ffffff"
            visible: Settings.data.wallpaper.wallhavenColors === parent.modelData
          }
        }
      }
    }
  }
}
