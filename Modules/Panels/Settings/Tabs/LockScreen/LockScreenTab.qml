import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
  id: root
  spacing: Style.marginL

  property string searchText: ""
  property bool showInstalledOnly: false

  readonly property var filteredThemes: {
    var result = LockThemeService.allThemes;
    if (showInstalledOnly) {
      result = result.filter(t => t.installed);
    }
    const query = searchText.trim().toLowerCase();
    if (query !== "") {
      result = result.filter(t => t.name.toLowerCase().includes(query));
    }
    return result;
  }

  Component.onCompleted: LockThemeService.fetchCatalog()

  NSettingsSection {
    icon: "lock"
    title: I18n.tr("panels.lock-screen.sddm-section-title")
    description: I18n.tr("panels.lock-screen.sddm-section-description")

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NTextInput {
        Layout.fillWidth: true
        placeholderText: I18n.tr("placeholders.search")
        text: root.searchText
        onTextChanged: root.searchText = text
      }

      NIconButton {
        icon: "filter"
        tooltipText: root.showInstalledOnly ? I18n.tr("actions.show-all") : I18n.tr("actions.show-active-only")
        colorBg: root.showInstalledOnly ? Color.mPrimary : Color.mSurface
        colorFg: root.showInstalledOnly ? Color.mOnPrimary : Color.mOnSurface
        onClicked: root.showInstalledOnly = !root.showInstalledOnly
      }

      NIconButton {
        icon: "refresh"
        tooltipText: I18n.tr("panels.lock-screen.sddm-refresh")
        onClicked: {
          LockThemeService.refreshInstalled();
          LockThemeService.fetchCatalog();
        }
      }

      NBusyIndicator {
        running: LockThemeService.isFetchingCatalog || LockThemeService.isRefreshingInstalled
        visible: running
        size: Math.round(Style.baseWidgetSize * 0.5)
      }
    }

    NGridView {
      id: themeGrid
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(cellHeight, Math.ceil(root.filteredThemes.length / Math.max(1, columns)) * cellHeight)
      readonly property int columns: Math.max(2, Math.floor(availableWidth / (260 * Style.uiScaleRatio)))
      cellWidth: Math.floor(availableWidth / columns)
      cellHeight: Math.round(cellWidth * 0.78) + Style.marginXS + Style.fontSizeS + Style.marginM
      model: root.filteredThemes
      interactive: false

      delegate: SddmThemeCard {
        required property var modelData
        width: themeGrid.cellWidth
        height: themeGrid.cellHeight
        themeData: modelData
      }
    }

    NText {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginM
      visible: root.filteredThemes.length === 0
      text: LockThemeService.isFetchingCatalog ? I18n.tr("panels.lock-screen.sddm-loading") : I18n.tr("common.no-results")
      color: Color.mOnSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
