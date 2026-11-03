import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  required property var launcher
  readonly property var resultsView: rowsView
  readonly property int responsiveColumns: Math.max(1, Math.min(3, Math.floor((rowsView.width + Style.marginM) / (270 * Style.uiScaleRatio + Style.marginM))))
  readonly property int columns: launcher.layoutMode === "list" ? 1 : (launcher.layoutMode === "columns" ? Math.min(2, responsiveColumns) : responsiveColumns)
  readonly property real cardHeight: Math.round(72 * Style.uiScaleRatio)
  readonly property var catalog: visible ? buildCatalog(launcher.results, columns) : ({ rows: [], locations: {}, letters: {}, order: [] })
  readonly property int selectedRow: catalog.locations[launcher.selectedIndex] !== undefined ? catalog.locations[launcher.selectedIndex].row : -1
  readonly property string alphabet: "#ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  readonly property int topRow: rowsView.indexAt(0, rowsView.contentY + 1)
  readonly property string currentLetter: catalog.rows.length > 0 ? catalog.rows[Math.max(0, Math.min(catalog.rows.length - 1, topRow))].letter : ""

  // Row positions are local to the catalog. Every entry and callback retains the
  // original provider result index; the provider's usage ordering is untouched.
  function buildCatalog(results, columnCount) {
    const ordered = [];
    for (let index = 0; index < results.length; ++index) {
      const entry = results[index];
      const name = String(entry.name || "").trim();
      const key = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
      const first = key.charAt(0);
      ordered.push({ index: index, name: name, key: key, letter: /^[A-Z]$/.test(first) ? first : "#", identity: String(entry.appId || "") });
    }
    ordered.sort((a, b) => {
      if (a.letter !== b.letter)
        return a.letter < b.letter ? -1 : 1;
      return a.key.localeCompare(b.key) || a.name.localeCompare(b.name) || a.identity.localeCompare(b.identity) || a.index - b.index;
    });
    const rows = [];
    const locations = {};
    const letters = {};
    let row = null;
    for (const app of ordered) {
      if (!row || row.letter !== app.letter || row.indices.length === columnCount) {
        const heading = !row || row.letter !== app.letter;
        row = { letter: app.letter, heading: heading, indices: [] };
        rows.push(row);
        if (heading)
          letters[app.letter] = rows.length - 1;
      }
      locations[app.index] = { row: rows.length - 1, column: row.indices.length };
      row.indices.push(app.index);
    }
    return { rows: rows, locations: locations, letters: letters, order: ordered.map(app => app.index) };
  }

  function jumpToIndex(index) {
    const location = catalog.locations[index];
    if (location === undefined)
      return;
    rowsView.cancelFlick();
    rowsView.positionViewAtIndex(location.row, ListView.Contain);
  }

  function selectIndex(index) {
    launcher.ignoreMouseHover = true;
    launcher.globalMouseInitialized = false;
    launcher.selectedIndex = index;
    jumpToIndex(index);
  }

  function selectFirst() {
    if (catalog.order.length > 0) selectIndex(catalog.order[0]);
  }
  function focusFirst() {
    selectFirst();
    forceActiveFocus(Qt.TabFocusReason);
  }

  function jumpToLetter(letter) {
    const row = catalog.letters[letter];
    if (row === undefined)
      return;
    if (launcher.appPanelOpen)
      launcher.closeAppPanel();
    selectIndex(catalog.rows[row].indices[0]);
    rowsView.positionViewAtIndex(row, ListView.Beginning);
  }

  function moveRow(location, delta) {
    let row = location.row + delta;
    const count = catalog.rows.length;
    row = launcher.allowWrapNavigation ? ((row % count) + count) % count : Math.max(0, Math.min(count - 1, row));
    const indices = catalog.rows[row].indices;
    selectIndex(indices[Math.min(location.column, indices.length - 1)]);
  }

  function navigate(event) {
    if (!visible)
      return false;
    launcher.ignoreMouseHover = true;
    launcher.globalMouseInitialized = false;
    if (launcher.appPanelOpen) {
      if (launcher.handleAppPanelKeyPress(event))
        return true;
      if (event.key === Qt.Key_Home || event.key === Qt.Key_End || event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
        event.accepted = true;
        return true;
      }
      return false;
    }
    const order = catalog.order;
    if (order.length === 0)
      return false;
    const index = order.indexOf(launcher.selectedIndex);
    const location = catalog.locations[launcher.selectedIndex];
    if (launcher.checkKey(event, "enter")) {
      launcher.activateEntry(launcher.results[launcher.selectedIndex]);
    } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
      launcher.openAppPanel(launcher.results[launcher.selectedIndex]);
    } else if (event.key === Qt.Key_Home) {
      selectIndex(order[0]);
    } else if (event.key === Qt.Key_End) {
      selectIndex(order[order.length - 1]);
    } else if (launcher.checkKey(event, "up") || launcher.checkKey(event, "down")) {
      if (location === undefined)
        selectIndex(order[0]);
      else
        moveRow(location, launcher.checkKey(event, "up") ? -1 : 1);
    } else if (launcher.checkKey(event, "left") || launcher.checkKey(event, "right")) {
      if (columns === 1)
        return false;
      let next = index + (launcher.checkKey(event, "left") ? -1 : 1);
      next = launcher.allowWrapNavigation ? ((next % order.length) + order.length) % order.length : Math.max(0, Math.min(order.length - 1, next));
      selectIndex(order[next]);
    } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
      const page = Math.max(1, Math.floor(rowsView.height / (cardHeight + Style.marginM)));
      if (location === undefined)
        selectIndex(order[0]);
      else {
        const row = Math.max(0, Math.min(catalog.rows.length - 1, location.row + (event.key === Qt.Key_PageUp ? -page : page)));
        const indices = catalog.rows[row].indices;
        selectIndex(indices[Math.min(location.column, indices.length - 1)]);
      }
    } else {
      return false;
    }
    event.accepted = true;
    return true;
  }

  Keys.onPressed: event => launcher.handleKeyPress(event)
  onCatalogChanged: Qt.callLater(() => { if (root.visible) root.jumpToIndex(root.launcher.selectedIndex); })
  onVisibleChanged: if (visible) Qt.callLater(() => root.jumpToIndex(root.launcher.selectedIndex))

  Connections {
    target: root.launcher
    function onSelectedIndexChanged() {
      if (root.visible)
        root.jumpToIndex(root.launcher.selectedIndex);
    }
    function onAppPanelItemChanged() {
      if (root.visible && root.launcher.appPanelOpen)
        Qt.callLater(() => root.jumpToIndex(root.launcher.appPanelIndex));
    }
  }

  ListView {
    id: rowsView
    anchors.left: parent.left
    anchors.right: letterRail.left
    anchors.rightMargin: Style.marginM
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    clip: true
    model: root.catalog.rows
    currentIndex: root.selectedRow
    highlightFollowsCurrentItem: false
    keyNavigationEnabled: false
    reuseItems: true
    cacheBuffer: height
    boundsBehavior: Flickable.StopAtBounds
    interactive: !Settings.data.appLauncher.ignoreMouseInput
    delegate: LauncherCatalogRow {
      width: rowsView.width
      launcher: root.launcher
      columns: root.columns
      cardHeight: root.cardHeight
    }
  }

  NBox {
    id: letterRail
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.baseWidgetSize * Style.uiScaleRatio + Style.marginXS
    radius: Style.radiusL
    color: HydraColor.mSurfaceContainerLow
    forceOpaque: true
    border.width: 0
    visible: root.catalog.order.length > 0

    ListView {
      id: lettersView
      anchors.fill: parent
      anchors.margins: Style.marginXXS
      clip: true
      currentIndex: root.alphabet.indexOf(root.currentLetter)
      highlightFollowsCurrentItem: false
      onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
      model: root.alphabet.split("")
      boundsBehavior: Flickable.StopAtBounds
      keyNavigationEnabled: false
      interactive: !Settings.data.appLauncher.ignoreMouseInput && contentHeight > height
      delegate: AbstractButton {
        id: letterButton
        required property string modelData
        required property int index
        readonly property bool available: root.catalog.letters[modelData] !== undefined
        readonly property bool current: root.currentLetter === modelData
        width: lettersView.width
        height: Math.max(Style.marginXL, Math.min(Style.marginXL + Style.marginS, lettersView.height / root.alphabet.length))
        enabled: available
        hoverEnabled: !Settings.data.appLauncher.ignoreMouseInput
        focusPolicy: Qt.StrongFocus
        Accessible.name: qsTr("Jump to %1").arg(modelData)
        Accessible.role: Accessible.Button
        Accessible.selected: current
        background: NStateLayer {
          baseColor: letterButton.current ? HydraColor.mPrimary : "transparent"
          stateColor: letterButton.current ? HydraColor.mOnPrimary : HydraColor.mOnSurface
          hovering: letterButton.hovered && !root.launcher.ignoreMouseHover
          pressed: letterButton.down
          focusVisible: letterButton.visualFocus
          radius: Style.radiusS
        }
        contentItem: NText {
          text: letterButton.modelData
          pointSize: Style.fontSizeXS
          font.weight: letterButton.current ? Style.fontWeightBold : Style.fontWeightRegular
          color: letterButton.current ? HydraColor.mOnPrimary : Qt.alpha(HydraColor.mOnSurfaceVariant, letterButton.available ? 1 : 0.35)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        onClicked: root.jumpToLetter(modelData)
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: Settings.data.appLauncher.ignoreMouseInput
      acceptedButtons: Qt.AllButtons
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    width: Math.max(0, parent.width - Style.margin2XL)
    spacing: Style.marginM
    visible: root.catalog.order.length === 0
    NIcon {
      Layout.alignment: Qt.AlignHCenter
      icon: "apps"
      pointSize: Style.fontSizeXXXL
      color: HydraColor.mOnSurfaceVariant
    }
    NText {
      Layout.fillWidth: true
      text: root.launcher.currentProvider.emptyBrowsingMessage || I18n.tr("common.no-results")
      color: HydraColor.mOnSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }
  }
}
