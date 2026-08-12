import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

// Card de uma fonte de captura (tela ou janela).
//
// Telas usam miniatura estática do grim; janelas usam ScreencopyView ao vivo.
Rectangle {
  id: root

  property string title: ""
  property string subtitle: ""
  property string badgeText: ""
  property string appIcon: ""

  // Miniatura estática (telas). Caminho de arquivo já com cache-buster.
  property string thumbnailPath: ""

  // Fonte de captura ao vivo (janelas): Toplevel genérico do Wayland.
  property var liveSource: null

  property bool selected: false
  property string emptyIcon: "device-desktop"

  signal clicked
  signal activated

  radius: Style.radiusM
  color: root.selected ? Color.mPrimaryContainer : (hoverHandler.hovered ? Color.mSurfaceContainerHigh : Color.mSurfaceContainerLow)
  border.width: root.selected ? Style.borderM : Style.borderS
  border.color: root.selected ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.5)

  Behavior on color {
    enabled: !Color.isTransitioning
    ColorAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }
  Behavior on border.color {
    enabled: !Color.isTransitioning
    ColorAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  HoverHandler {
    id: hoverHandler
  }

  TapHandler {
    onSingleTapped: root.clicked()
    onDoubleTapped: root.activated()
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginS

    // --- área da miniatura ----------------------------------------------------

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.radiusXS
      color: Color.mSurface
      border.width: Style.borderS
      border.color: Qt.alpha(Color.mOutline, 0.4)
      clip: true

      // Placeholder enquanto nada foi capturado.
      NIcon {
        anchors.centerIn: parent
        visible: root.thumbnailPath === "" && root.liveSource === null
        icon: root.emptyIcon
        pointSize: Style.fontSizeXXXL
        color: Qt.alpha(Color.mOnSurfaceVariant, 0.5)
      }

      NImageRounded {
        anchors.fill: parent
        anchors.margins: Style.borderS
        visible: root.thumbnailPath !== ""
        radius: Style.radiusXS
        imagePath: root.thumbnailPath
        imageFillMode: Image.PreserveAspectFit
        borderWidth: 0
      }

      Loader {
        anchors.fill: parent
        anchors.margins: Style.borderS
        active: root.liveSource !== null
        asynchronous: true
        sourceComponent: Component {
          ScreencopyView {
            captureSource: root.liveSource
            live: true
          }
        }
      }

      // Ícone do app sobreposto, canto inferior esquerdo.
      NImageRounded {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Style.marginXS
        visible: root.appIcon !== ""
        width: Style.fontSizeXXL * 1.2
        height: Style.fontSizeXXL * 1.2
        radius: Style.radiusXS
        imagePath: root.appIcon
        borderWidth: 0
      }

      // Marca de seleção, canto superior direito.
      Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.marginXS
        visible: root.selected
        width: Style.fontSizeXL * 1.4
        height: width
        radius: width / 2
        color: Color.mPrimary

        NIcon {
          anchors.centerIn: parent
          icon: "check"
          pointSize: Style.fontSizeS
          color: Color.mOnPrimary
        }
      }
    }

    // --- rótulos --------------------------------------------------------------

    NText {
      Layout.fillWidth: true
      text: root.title
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightSemiBold
      color: root.selected ? Color.mOnPrimaryContainer : Color.mOnSurface
      elide: Text.ElideRight
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        Layout.fillWidth: true
        visible: root.subtitle !== ""
        text: root.subtitle
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
        elide: Text.ElideRight
      }

      // Pílula com a classe do app / identificador técnico.
      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        visible: root.badgeText !== ""
        radius: height / 2
        color: Qt.alpha(Color.mPrimary, 0.16)
        implicitWidth: badgeLabel.implicitWidth + Style.marginS * 2
        implicitHeight: badgeLabel.implicitHeight + Style.marginXXS * 2

        NText {
          id: badgeLabel
          anchors.centerIn: parent
          text: root.badgeText
          pointSize: Style.fontSizeXXS
          font.weight: Style.fontWeightSemiBold
          color: Color.mPrimary
        }
      }
    }
  }
}
