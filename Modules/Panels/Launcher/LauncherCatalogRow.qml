import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root
  required property int index

  required property var launcher
  required property var modelData
  required property int columns
  required property real cardHeight

  readonly property real headingHeight: modelData.heading ? Style.margin2XL + Style.marginXS : 0
  readonly property real cellWidth: Math.max(0, (width - Style.marginM * (columns - 1)) / columns)
  readonly property int panelColumn: modelData.indices.indexOf(launcher.appPanelIndex)
  readonly property real panelGap: columns === 1 ? Style.marginXXS : Style.marginS

  implicitHeight: headingHeight + cardHeight + Style.marginM + (panelLoader.active ? panelLoader.height + panelGap : 0)
  height: implicitHeight

  RowLayout {
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.headingHeight
    spacing: Style.marginM
    visible: root.modelData.heading
    NText {
      text: root.modelData.letter
      pointSize: Style.fontSizeL
      font.weight: Style.fontWeightBold
      color: HydraColor.mOnSurface
      Accessible.role: Accessible.Heading
    }
    NDivider {
      Layout.fillWidth: true
      opacity: Style.opacityLight
    }
  }

  Row {
    id: cards
    y: root.headingHeight
    width: root.width
    height: root.cardHeight
    spacing: Style.marginM
    Repeater {
      model: root.modelData.indices
      delegate: LauncherCatalogCard {
        required property var modelData
        width: root.cellWidth
        height: root.cardHeight
        launcher: root.launcher
        entryIndex: modelData
        entry: root.launcher.results[entryIndex]
        connectedToPanel: root.columns === 1 && root.panelColumn >= 0
      }
    }
  }

  Rectangle {
    width: Style.marginM
    height: width
    rotation: 45
    color: panelLoader.status === Loader.Ready ? panelLoader.item.panelColor : HydraColor.mSurfaceContainerHigh
    visible: root.columns > 1 && root.panelColumn >= 0
    x: root.panelColumn >= 0 ? (root.panelColumn + 0.5) * root.cellWidth + root.panelColumn * Style.marginM - width / 2 : 0
    y: panelLoader.y - height / 2
    Accessible.ignored: true
  }

  Loader {
    id: panelLoader
    y: cards.y + cards.height + root.panelGap
    width: root.width
    height: status === Loader.Ready ? item.height : 0
    active: root.panelColumn >= 0
    sourceComponent: LauncherAppActionsPanel {
      width: panelLoader.width
      launcher: root.launcher
      item: root.launcher.appPanelItem
      actions: root.launcher.appPanelActions
      propertiesApp: root.launcher.propertiesApp
      showingProperties: root.launcher.appPanelShowingProperties
      activeActionIndex: root.launcher.appPanelActionIndex
      confirmIndex: root.launcher.appPanelConfirmIndex
      connectedToEntry: root.columns === 1
      open: true
      onHeightChanged: root.ensurePanelVisible()
    }
  }

  function ensurePanelVisible() {
    if (panelLoader.active && root.ListView.view)
      Qt.callLater(() => {
        if (panelLoader.active && root.ListView.view)
          root.ListView.view.positionViewAtIndex(root.index, ListView.Contain);
      });
  }
}
