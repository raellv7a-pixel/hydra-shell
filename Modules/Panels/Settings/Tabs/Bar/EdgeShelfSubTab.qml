pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property bool isFramed: Settings.data.bar.barType === "framed"
  readonly property var pinnedApps: (Settings.data.edgeShelf && Settings.data.edgeShelf.pinnedApps) ? Settings.data.edgeShelf.pinnedApps : []

  function getAppName(appId) {
    if (!appId)
      return "";
    const entry = ThemeIcons.findAppEntry(appId);
    if (entry && entry.name)
      return entry.name;
    let clean = appId.replace(/\.desktop$/i, "");
    return clean.charAt(0).toUpperCase() + clean.slice(1);
  }

  function getAppIcon(appId) {
    if (!appId)
      return "";
    return ThemeIcons.iconForAppId(appId.toLowerCase()) || "";
  }

  function removeApp(index) {
    if (index >= 0 && index < root.pinnedApps.length)
      EdgeShelfService.removePinnedApp(root.pinnedApps[index]);
  }

  function moveApp(fromIndex, toIndex) {
    if (!Settings.data.edgeShelf)
      return;
    let arr = root.pinnedApps.slice();
    if (fromIndex >= 0 && fromIndex < arr.length && toIndex >= 0 && toIndex < arr.length) {
      const item = arr.splice(fromIndex, 1)[0];
      arr.splice(toIndex, 0, item);
      Settings.data.edgeShelf.pinnedApps = arr;
    }
  }

  // Notice when Framed mode is not active
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: frameNoticeLayout.implicitHeight + Style.marginM * 2
    visible: !root.isFramed
    color: Color.mSurfaceVariant
    radius: Style.radiusM
    border.color: Qt.alpha(Color.mOutline, 0.55)
    border.width: Style.borderS

    RowLayout {
      id: frameNoticeLayout
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NIcon {
        icon: "info-circle"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: I18n.tr("panels.bar.edge-shelf-requires-frame-title") ?? "O Edge Shelf requer a barra no estilo Emoldurado"
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeM
        }

        NText {
          text: I18n.tr("panels.bar.edge-shelf-requires-frame-desc") ?? "O Edge Shelf é uma superfície lateral integrada à moldura. Ative o estilo 'Emoldurado' na aba Aparência para utilizá-lo."
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }
  }

  // Edge Shelf Enable Toggle
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.edge-shelf-enable-label") ?? "Ativar Edge Shelf"
    description: I18n.tr("panels.bar.edge-shelf-enable-description") ?? "Superfície lateral recolhível na moldura para aplicativos rápidos"
    checked: Settings.data.edgeShelf ? Settings.data.edgeShelf.enabled : false
    defaultValue: Settings.getDefaultValue("edgeShelf.enabled") ?? false
    onToggled: checked => {
      if (Settings.data.edgeShelf) {
        Settings.data.edgeShelf.enabled = checked;
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Pinned Apps Header
  NHeader {
    label: I18n.tr("panels.bar.edge-shelf-apps-label") ?? "Aplicativos no Edge Shelf"
    description: I18n.tr("panels.bar.edge-shelf-apps-description") ?? "Gerencie os aplicativos do Edge Shelf. Use o menu de contexto no Lançador para adicionar novos."
  }

  // Empty state
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 70
    visible: root.pinnedApps.length === 0
    color: "transparent"
    radius: Style.radiusM
    border.color: Qt.alpha(Color.mOutline, 0.55)
    border.width: Style.borderS

    RowLayout {
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "layout-sidebar-right"
        pointSize: Style.fontSizeL
        color: Color.mOnSurfaceVariant
      }

      NText {
        text: I18n.tr("panels.bar.edge-shelf-empty-hint") ?? "Nenhum aplicativo adicionado. Abra o Lançador, clique com o botão direito em um app e selecione 'Adicionar ao Edge Shelf'."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }
  }

  // List of apps
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    visible: root.pinnedApps.length > 0

    Repeater {
      model: root.pinnedApps

      delegate: Rectangle {
        id: appRow
        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredHeight: appRowContent.implicitHeight + Style.marginS * 2
        radius: Style.radiusM
        color: Color.mSurfaceVariant
        border.color: Qt.alpha(Color.mOutline, 0.55)
        border.width: Style.borderS

        RowLayout {
          id: appRowContent
          anchors.fill: parent
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginS
          spacing: Style.marginM

          // App Icon
          Image {
            Layout.preferredWidth: Style.baseWidgetSize * 0.85 * Style.uiScaleRatio
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            source: root.getAppIcon(appRow.modelData)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
          }

          // App Name and ID
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 0
            spacing: Style.marginXXS

            NText {
              Layout.fillWidth: true
              text: root.getAppName(appRow.modelData)
              elide: Text.ElideRight
              font.weight: Style.fontWeightMedium
              pointSize: Style.fontSizeM
            }

            NText {
              Layout.fillWidth: true
              text: appRow.modelData
              elide: Text.ElideRight
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
            }
          }

          // A fixed, compact trailing group keeps all actions with their app.
          RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.fillWidth: false
            spacing: Style.marginXXS

            NIconButton {
              icon: "chevron-up"
              baseSize: Style.baseWidgetSize * 0.85
              customRadius: Style.iRadiusS
              colorBg: "transparent"
              colorBorder: "transparent"
              colorFg: Color.mOnSurfaceVariant
              tooltipText: I18n.tr("common.move-up")
              enabled: appRow.index > 0
              onClicked: root.moveApp(appRow.index, appRow.index - 1)
            }

            NIconButton {
              icon: "chevron-down"
              baseSize: Style.baseWidgetSize * 0.85
              customRadius: Style.iRadiusS
              colorBg: "transparent"
              colorBorder: "transparent"
              colorFg: Color.mOnSurfaceVariant
              tooltipText: I18n.tr("common.move-down")
              enabled: appRow.index < root.pinnedApps.length - 1
              onClicked: root.moveApp(appRow.index, appRow.index + 1)
            }

            NIconButton {
              Layout.leftMargin: Style.marginS
              icon: "trash"
              baseSize: Style.baseWidgetSize * 0.85
              customRadius: Style.iRadiusS
              colorBg: "transparent"
              colorBorder: "transparent"
              colorFg: Color.mOnSurfaceVariant
              tooltipText: I18n.tr("common.remove")
              onClicked: root.removeApp(appRow.index)
            }
          }
        }
      }
    }
  }
}
