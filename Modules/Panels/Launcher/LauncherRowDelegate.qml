import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

// One row of launcher results. Every layout mode (list, columns, grid) is built
// from rows so the inline app panel can expand full-width underneath a row and
// push the following rows down — something a GridView's fixed cell grid cannot
// express, and which a per-entry panel would get clipped by.
Item {
  id: rowRoot

  required property int index // row index
  required property var launcher

  // Set by the view that owns this delegate.
  property int columns: 1
  property real rowHeight: 0
  property bool useCards: false // grid cards vs. list entries

  readonly property int firstEntryIndex: index * columns
  readonly property real cellWidth: width / Math.max(1, columns)

  // Inset the cells use, so the panel can line up with the entry above it
  // instead of overhanging it by a couple of pixels.
  readonly property real cellInset: useCards ? 0 : Style.marginXXS

  // A single-column panel fuses with its entry; wider layouts point at it.
  readonly property bool fusedWithEntry: columns === 1
  readonly property real panelGap: fusedWithEntry ? Style.marginXXS : Style.marginS

  // Column holding the app whose panel is open, or -1 when this row has none.
  readonly property int panelColumn: {
    const entryIndex = launcher.appPanelIndex;
    if (entryIndex < 0 || Math.floor(entryIndex / columns) !== index)
      return -1;
    return entryIndex % columns;
  }

  width: ListView.view ? ListView.view.width : 0
  implicitHeight: rowRoot.rowHeight + (panel.height > 0.5 ? panel.height + rowRoot.panelGap : 0)
  z: panelColumn >= 0 ? 10 : 0

  Row {
    id: cellsRow
    width: parent.width
    height: rowRoot.rowHeight
    spacing: 0

    Repeater {
      model: rowRoot.columns

      delegate: Item {
        id: cell

        required property int index // column index
        readonly property int entryIndex: rowRoot.firstEntryIndex + index
        readonly property var entry: rowRoot.launcher.results[entryIndex] || null

        width: rowRoot.cellWidth
        height: rowRoot.rowHeight

        Loader {
          anchors.fill: parent
          anchors.margins: rowRoot.cellInset
          active: cell.entry !== null
          sourceComponent: rowRoot.useCards ? cardComponent : entryComponent
        }

        Component {
          id: cardComponent
          LauncherGridDelegate {
            modelData: cell.entry
            entryIndex: cell.entryIndex
            launcher: rowRoot.launcher
          }
        }

        Component {
          id: entryComponent
          LauncherListDelegate {
            modelData: cell.entry
            entryIndex: cell.entryIndex
            launcher: rowRoot.launcher
          }
        }
      }
    }
  }

  // Caret pointing back at the app the panel belongs to. Only multi-column
  // layouts need it: a single-column panel is already fused with its entry.
  Rectangle {
    width: Style.marginM
    height: width
    rotation: 45
    color: panel.panelColor
    visible: !rowRoot.fusedWithEntry && panel.open && panel.height > 0.5
    x: rowRoot.panelColumn >= 0 ? (rowRoot.panelColumn + 0.5) * rowRoot.cellWidth - width / 2 : 0
    y: panel.y - height / 2
    z: 101

    Behavior on x {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
  }

  LauncherAppActionsPanel {
    id: panel

    x: rowRoot.cellInset
    y: cellsRow.height + rowRoot.panelGap
    width: Math.max(0, rowRoot.width - rowRoot.cellInset * 2)
    launcher: rowRoot.launcher
    item: rowRoot.launcher.appPanelItem
    actions: rowRoot.launcher.appPanelActions
    propertiesApp: rowRoot.launcher.propertiesApp
    showingProperties: rowRoot.launcher.appPanelShowingProperties
    activeActionIndex: rowRoot.launcher.appPanelActionIndex
    confirmIndex: rowRoot.launcher.appPanelConfirmIndex
    connectedToEntry: rowRoot.fusedWithEntry
    open: rowRoot.panelColumn >= 0
  }
}
