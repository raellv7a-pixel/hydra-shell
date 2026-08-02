import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

RowLayout {
  id: root
  Layout.fillWidth: true
  spacing: Style.marginM

  // Expose signal to request search
  signal searchRequested()

  // Sorting
  NComboBox {
    id: quickSortCombo
    Layout.preferredWidth: 160
    model: [
      { "key": "relevance", "name": I18n.tr("wallpaper.panel.sorting-relevance") || "Relevância" },
      { "key": "date_added", "name": I18n.tr("wallpaper.panel.sorting-date-added") || "Data" },
      { "key": "random", "name": I18n.tr("common.random") || "Aleatório" },
      { "key": "views", "name": I18n.tr("wallpaper.panel.sorting-views") || "Visualizações" },
      { "key": "favorites", "name": I18n.tr("wallpaper.panel.sorting-favorites") || "Favoritos" },
      { "key": "toplist", "name": I18n.tr("wallpaper.panel.sorting-toplist") || "Toplist" }
    ]
    currentKey: Settings.data.wallpaper.wallhavenSorting || "relevance"
    
    Connections {
      target: Settings.data.wallpaper
      function onWallhavenSortingChanged() {
        if (quickSortCombo.currentKey !== Settings.data.wallpaper.wallhavenSorting) {
          quickSortCombo.currentKey = Settings.data.wallpaper.wallhavenSorting || "relevance";
        }
      }
    }
    
    onSelected: key => {
      Settings.data.wallpaper.wallhavenSorting = key;
      if (typeof WallhavenService !== "undefined") {
        WallhavenService.sorting = key;
        root.searchRequested();
      }
    }
  }

  // Top Range (only if toplist)
  NComboBox {
    id: quickTopRangeCombo
    visible: quickSortCombo.currentKey === "toplist"
    Layout.preferredWidth: 120
    model: [
      { "key": "1d", "name": "1 Dia" },
      { "key": "3d", "name": "3 Dias" },
      { "key": "1w", "name": "1 Semana" },
      { "key": "1M", "name": "1 Mês" },
      { "key": "3M", "name": "3 Meses" },
      { "key": "6M", "name": "6 Meses" },
      { "key": "1y", "name": "1 Ano" }
    ]
    currentKey: Settings.data.wallpaper.wallhavenTopRange || "1M"
    
    Connections {
      target: Settings.data.wallpaper
      function onWallhavenTopRangeChanged() {
        if (quickTopRangeCombo.currentKey !== Settings.data.wallpaper.wallhavenTopRange) {
          quickTopRangeCombo.currentKey = Settings.data.wallpaper.wallhavenTopRange || "1M";
        }
      }
    }

    onSelected: key => {
      Settings.data.wallpaper.wallhavenTopRange = key;
      if (typeof WallhavenService !== "undefined") {
        WallhavenService.topRange = key;
        root.searchRequested();
      }
    }
  }

  Item { Layout.fillWidth: true } // Spacer

  // Categories (General, Anime, People)
  RowLayout {
    spacing: Style.marginS

    function toggleCategory(index, checked) {
      var cats = Settings.data.wallpaper.wallhavenCategories || "111";
      var arr = cats.split("");
      while (arr.length < 3) arr.push("1");
      arr[index] = checked ? "1" : "0";
      var newCats = arr.join("");
      Settings.data.wallpaper.wallhavenCategories = newCats;
      if (typeof WallhavenService !== "undefined") {
        WallhavenService.categories = newCats;
        root.searchRequested();
      }
    }

    function isChecked(index) {
      return (Settings.data.wallpaper.wallhavenCategories || "111").charAt(index) === "1";
    }

    // Workaround since Settings connections on properties aren't always immediate
    Connections {
      target: Settings.data.wallpaper
      function onWallhavenCategoriesChanged() {
        catGen.checked = rootCategories.isChecked(0);
        catAni.checked = rootCategories.isChecked(1);
        catPeo.checked = rootCategories.isChecked(2);
      }
    }
    
    id: rootCategories

    NButton {
      id: catGen
      text: I18n.tr("common.general") || "Geral"
      property bool checked: rootCategories.isChecked(0)
      backgroundColor: checked ? Color.mPrimary : Color.mSurfaceVariant
      textColor: checked ? Color.mOnPrimary : Color.mOnSurface
      onClicked: rootCategories.toggleCategory(0, !checked)
    }
    NButton {
      id: catAni
      text: I18n.tr("wallpaper.panel.categories-anime") || "Anime"
      property bool checked: rootCategories.isChecked(1)
      backgroundColor: checked ? Color.mPrimary : Color.mSurfaceVariant
      textColor: checked ? Color.mOnPrimary : Color.mOnSurface
      onClicked: rootCategories.toggleCategory(1, !checked)
    }
    NButton {
      id: catPeo
      text: I18n.tr("wallpaper.panel.categories-people") || "Pessoas"
      property bool checked: rootCategories.isChecked(2)
      backgroundColor: checked ? Color.mPrimary : Color.mSurfaceVariant
      textColor: checked ? Color.mOnPrimary : Color.mOnSurface
      onClicked: rootCategories.toggleCategory(2, !checked)
    }
  }

  // Color Picker Button
  NIconButton {
    id: colorBtn
    icon: "palette"
    tooltipText: "Filtro de Cor"
    property string activeColor: Settings.data.wallpaper.wallhavenColors || ""
    colorBg: activeColor !== "" ? "#" + activeColor : Color.mSurfaceVariant
    colorFg: activeColor !== "" ? "#ffffff" : Color.mOnSurface
    onClicked: {
      colorPopup.showAt(colorBtn)
    }
    
    WallhavenColorPopup {
      id: colorPopup
      onColorSelected: colorHex => {
        Settings.data.wallpaper.wallhavenColors = colorHex;
        if (typeof WallhavenService !== "undefined") {
          WallhavenService.colors = colorHex;
          root.searchRequested();
        }
      }
    }
  }
}
