import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  Layout.fillWidth: true
  spacing: Style.marginS

  signal searchRequested

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NComboBox {
      id: quickSortCombo
      Layout.preferredWidth: 160 * Style.uiScaleRatio
      Layout.fillWidth: true
      model: [
        {
          "key": "relevance",
          "name": I18n.tr("wallpaper.panel.sorting-relevance")
        },
        {
          "key": "date_added",
          "name": I18n.tr("wallpaper.panel.sorting-date-added")
        },
        {
          "key": "random",
          "name": I18n.tr("common.random")
        },
        {
          "key": "views",
          "name": I18n.tr("wallpaper.panel.sorting-views")
        },
        {
          "key": "favorites",
          "name": I18n.tr("wallpaper.panel.sorting-favorites")
        },
        {
          "key": "toplist",
          "name": I18n.tr("wallpaper.panel.sorting-toplist")
        }
      ]
      currentKey: Settings.data.wallpaper.wallhavenSorting || "relevance"

      Connections {
        target: Settings.data.wallpaper
        function onWallhavenSortingChanged() {
          const key = Settings.data.wallpaper.wallhavenSorting || "relevance";
          if (quickSortCombo.currentKey !== key) {
            quickSortCombo.currentKey = key;
          }
        }
      }

      onSelected: key => {
        Settings.data.wallpaper.wallhavenSorting = key;
        WallhavenService.sorting = key;
        root.searchRequested();
      }
    }

    NComboBox {
      id: quickTopRangeCombo
      visible: quickSortCombo.currentKey === "toplist"
      Layout.preferredWidth: 120 * Style.uiScaleRatio
      model: [
        {
          "key": "1d",
          "name": I18n.tr("wallpaper.panel.range-1d")
        },
        {
          "key": "3d",
          "name": I18n.tr("wallpaper.panel.range-3d")
        },
        {
          "key": "1w",
          "name": I18n.tr("wallpaper.panel.range-1w")
        },
        {
          "key": "1M",
          "name": I18n.tr("wallpaper.panel.range-1m")
        },
        {
          "key": "3M",
          "name": I18n.tr("wallpaper.panel.range-3m")
        },
        {
          "key": "6M",
          "name": I18n.tr("wallpaper.panel.range-6m")
        },
        {
          "key": "1y",
          "name": I18n.tr("wallpaper.panel.range-1y")
        }
      ]
      currentKey: Settings.data.wallpaper.wallhavenTopRange || "1M"

      Connections {
        target: Settings.data.wallpaper
        function onWallhavenTopRangeChanged() {
          const key = Settings.data.wallpaper.wallhavenTopRange || "1M";
          if (quickTopRangeCombo.currentKey !== key) {
            quickTopRangeCombo.currentKey = key;
          }
        }
      }

      onSelected: key => {
        Settings.data.wallpaper.wallhavenTopRange = key;
        WallhavenService.topRange = key;
        root.searchRequested();
      }
    }

    NComboBox {
      id: quickOrderCombo
      Layout.preferredWidth: 124 * Style.uiScaleRatio
      model: [
        {
          "key": "desc",
          "name": I18n.tr("wallpaper.panel.order-desc")
        },
        {
          "key": "asc",
          "name": I18n.tr("wallpaper.panel.order-asc")
        }
      ]
      currentKey: Settings.data.wallpaper.wallhavenOrder || "desc"

      Connections {
        target: Settings.data.wallpaper
        function onWallhavenOrderChanged() {
          const key = Settings.data.wallpaper.wallhavenOrder || "desc";
          if (quickOrderCombo.currentKey !== key) {
            quickOrderCombo.currentKey = key;
          }
        }
      }

      onSelected: key => {
        Settings.data.wallpaper.wallhavenOrder = key;
        WallhavenService.order = key;
        root.searchRequested();
      }
    }
  }

  RowLayout {
    id: categoryRow
    Layout.fillWidth: true
    spacing: Style.marginS

    function isChecked(index) {
      return (Settings.data.wallpaper.wallhavenCategories || "111").charAt(index) === "1";
    }

    function toggleCategory(index, checked) {
      const categories = (Settings.data.wallpaper.wallhavenCategories || "111").padEnd(3, "1").split("");
      categories[index] = checked ? "1" : "0";
      const nextCategories = categories.join("");
      if (nextCategories === "000") {
        return;
      }
      Settings.data.wallpaper.wallhavenCategories = nextCategories;
      WallhavenService.categories = nextCategories;
      root.searchRequested();
    }

    NButton {
      id: categoryGeneral
      property bool checked: categoryRow.isChecked(0)
      text: I18n.tr("common.general")
      backgroundColor: checked ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
      textColor: checked ? Color.mOnSecondaryContainer : Color.mOnSurface
      onClicked: categoryRow.toggleCategory(0, !checked)
    }

    NButton {
      id: categoryAnime
      property bool checked: categoryRow.isChecked(1)
      text: I18n.tr("wallpaper.panel.categories-anime")
      backgroundColor: checked ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
      textColor: checked ? Color.mOnSecondaryContainer : Color.mOnSurface
      onClicked: categoryRow.toggleCategory(1, !checked)
    }

    NButton {
      id: categoryPeople
      property bool checked: categoryRow.isChecked(2)
      text: I18n.tr("wallpaper.panel.categories-people")
      backgroundColor: checked ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
      textColor: checked ? Color.mOnSecondaryContainer : Color.mOnSurface
      onClicked: categoryRow.toggleCategory(2, !checked)
    }

    Item {
      Layout.fillWidth: true
    }

    NIconButton {
      id: colorButton
      property string activeColor: Settings.data.wallpaper.wallhavenColors || ""
      icon: "palette"
      tooltipText: I18n.tr("wallpaper.panel.color-filter")
      colorBg: activeColor !== "" ? "#" + activeColor : Color.mSurfaceContainerHigh
      colorFg: activeColor !== "" ? "#ffffff" : Color.mOnSurface
      colorBorder: activeColor !== "" ? Color.mOnSurface : "transparent"
      colorBorderHover: Color.mPrimary
      onClicked: colorPopup.showAt(colorButton)

      WallhavenColorPopup {
        id: colorPopup
        onColorSelected: colorHex => {
          Settings.data.wallpaper.wallhavenColors = colorHex;
          WallhavenService.colors = colorHex;
          root.searchRequested();
        }
      }
    }
  }
}
