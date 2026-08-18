import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

// Inline panel that expands inside the launcher, under the app it belongs to.
// It hosts the per-app actions (pin, hide, update, uninstall) and doubles as the
// app properties view.
//
// Visually it is the bottom half of a Material 3 connected group: the entry above
// keeps its rounded top, the panel keeps its rounded bottom, and the two facing
// corners are tightened so the pair reads as one expanded card instead of two
// unrelated boxes. Colors follow tonal elevation (a step above the launcher
// surface, tinted with the accent) rather than an outline.
Item {
  id: root

  property var launcher: null
  property var item: null
  property var actions: []
  property var propertiesApp: null
  property bool open: false
  property bool showingProperties: false
  // Both indices are owned by the launcher so that mouse and keyboard share one
  // cursor: -1 means "nothing selected" / "nothing awaiting confirmation".
  property int activeActionIndex: -1
  property int confirmIndex: -1
  // True when the panel sits directly under its own entry (single column), so the
  // two shapes can be fused. Multi-column layouts point at the entry with a caret
  // instead, because the panel spans the whole row.
  property bool connectedToEntry: true

  // ------------------------------------------------------------------
  // Content lifetime
  //
  // The launcher drops item/actions the instant the panel closes, so the collapse
  // animation would otherwise play on an empty box. Keep the last known values
  // and tear the content down only once the panel has finished shrinking — while
  // still never materializing rows on the dozens of row delegates whose panel is
  // closed.
  property var _lastItem: null
  property var _lastActions: []
  property bool contentAlive: false

  onItemChanged: {
    if (item)
      _lastItem = item;
  }

  onActionsChanged: {
    if (actions && actions.length > 0)
      _lastActions = actions;
  }

  onOpenChanged: {
    if (open) {
      collapseTimer.stop();
      contentAlive = true;
    } else if (Style.animationNormal <= 0) {
      contentAlive = false;
    } else {
      collapseTimer.restart();
    }
  }

  // A recycled row delegate can be created with its panel already open.
  Component.onCompleted: {
    if (open)
      contentAlive = true;
  }

  Timer {
    id: collapseTimer
    interval: Style.animationNormal + 50
    onTriggered: {
      if (!root.open)
        root.contentAlive = false;
    }
  }

  readonly property var shownItem: item || _lastItem
  readonly property var shownActions: (actions && actions.length > 0) ? actions : _lastActions
  readonly property var shownApp: propertiesApp || (shownItem ? (shownItem.appData || shownItem) : null)

  readonly property var provider: shownItem ? shownItem.provider : null
  readonly property string errorText: (open && provider && provider.shellyError) ? provider.shellyError : ""

  // Material 3 tonal surface: one step above the launcher's own container, with a
  // hint of the accent so it belongs to the highlighted entry above it.
  readonly property color panelColor: Color.blend(Color.mSurfaceContainerHigh, Color.mPrimary, 0.07)
  readonly property int seamRadius: Style.radiusXXS
  readonly property int outerRadius: Style.radiusL
  readonly property real rowHeight: Math.round(38 * Style.uiScaleRatio)
  // Shared leading column: keeps action rows and property rows on the same grid.
  readonly property real leadingSlot: Math.round(Style.fontSizeL * 1.7 * Style.uiScaleRatio)

  implicitHeight: contentLoader.implicitHeight
  height: open ? implicitHeight : 0
  visible: contentAlive
  opacity: open ? 1.0 : 0.0
  clip: true
  z: open ? 100 : 0

  Behavior on height {
    NAnim {
      motionType: NAnim.ExpressiveDefaultSpatial
    }
  }

  Behavior on opacity {
    NAnim {
      motionType: NAnim.StandardEffects
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.panelColor
    radius: root.outerRadius
    topLeftRadius: root.connectedToEntry ? root.seamRadius : root.outerRadius
    topRightRadius: root.connectedToEntry ? root.seamRadius : root.outerRadius

    Behavior on color {
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }
  }

  Loader {
    id: contentLoader
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: implicitHeight
    active: root.contentAlive
    sourceComponent: contentComponent
  }

  Component {
    id: contentComponent

    ColumnLayout {
      spacing: Style.marginXXS

      // ---------------------------------------------------------------
      // Overline header: names the section, and carries back/close so the
      // action list itself stays a clean, uniform stack of list items.
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginM
        Layout.rightMargin: Style.marginXS
        Layout.topMargin: Style.marginXS
        spacing: Style.marginXS

        NIconButton {
          visible: root.showingProperties
          icon: "arrow-left"
          tooltipText: I18n.tr("common.back")
          baseSize: Style.baseWidgetSize * 0.7
          colorBg: "transparent"
          colorBorder: "transparent"
          colorBorderHover: "transparent"
          colorFg: Color.mOnSurfaceVariant
          colorBgHover: Color.mPrimaryContainer
          colorFgHover: Color.mOnPrimaryContainer
          onClicked: {
            if (root.launcher)
              root.launcher.hideAppProperties();
          }
        }

        NText {
          Layout.fillWidth: true
          text: root.showingProperties ? I18n.tr("launcher.app-properties.description") : I18n.tr("launcher.app-actions.title")
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
        }

        NIconButton {
          icon: "close"
          tooltipText: I18n.tr("common.close")
          baseSize: Style.baseWidgetSize * 0.7
          colorBg: "transparent"
          colorBorder: "transparent"
          colorBorderHover: "transparent"
          colorFg: Color.mOnSurfaceVariant
          colorBgHover: Color.mPrimaryContainer
          colorFgHover: Color.mOnPrimaryContainer
          onClicked: root.requestClose()
        }
      }

      // ---------------------------------------------------------------
      // Actions
      ColumnLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Style.marginXS
        visible: !root.showingProperties
        spacing: 0

        Repeater {
          // A closed panel must not materialize any action rows: every row
          // delegate in the results list owns a panel instance.
          model: (root.contentAlive && !root.showingProperties) ? root.shownActions : []

          delegate: Item {
            id: actionRow

            required property var modelData
            required property int index

            readonly property bool isEnabled: modelData.enabled !== false && !modelData.busy
            readonly property bool isConfirming: root.confirmIndex === index
            readonly property bool isActive: root.activeActionIndex === index
            readonly property bool isDestructive: !!modelData.destructive

            readonly property color foreground: {
              if (isConfirming)
                return Color.mOnErrorContainer;
              if (isDestructive)
                return Color.mError;
              if (isActive && isEnabled)
                return Color.mOnPrimaryContainer;
              return Color.mOnSurface;
            }

            Layout.fillWidth: true
            Layout.leftMargin: Style.marginXS
            Layout.rightMargin: Style.marginXS
            Layout.preferredHeight: root.rowHeight
            // M3 disabled opacity; a busy row is still fully lit.
            opacity: (modelData.enabled === false && !modelData.busy) ? 0.38 : 1.0

            Behavior on opacity {
              NAnim {
                motionType: NAnim.StandardEffects
              }
            }

            // State layer
            Rectangle {
              anchors.fill: parent
              radius: Style.radiusS
              color: {
                if (actionRow.isConfirming)
                  return Color.mErrorContainer;
                if (actionRow.isActive && actionRow.isEnabled)
                  return actionRow.isDestructive ? Qt.alpha(Color.mError, 0.14) : Color.mPrimaryContainer;
                return "transparent";
              }

              Behavior on color {
                NColorAnimation {
                  duration: Style.motionDurationFastEffects
                }
              }
            }

            // Declared before the content so the confirmation chips, which sit on
            // top, get the click instead of the row.
            MouseArea {
              id: actionMouse
              anchors.fill: parent
              enabled: actionRow.isEnabled
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                // The launcher suppresses hover until the pointer actually moves,
                // so a panel expanding under a resting cursor doesn't grab it.
                if (root.launcher && !root.launcher.ignoreMouseHover)
                  root.launcher.setAppPanelActionIndex(actionRow.index);
              }
              onExited: {
                if (root.launcher && root.activeActionIndex === actionRow.index)
                  root.launcher.setAppPanelActionIndex(-1);
              }
              onClicked: {
                // While armed, only the explicit chips decide.
                if (actionRow.isConfirming)
                  return;
                if (root.launcher)
                  root.launcher.activateAppPanelAction(actionRow.index);
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginS
              anchors.rightMargin: Style.marginS
              spacing: Style.marginS

              // Fixed leading slot so swapping the icon for the spinner never
              // shifts the label.
              Item {
                Layout.preferredWidth: root.leadingSlot
                Layout.preferredHeight: root.leadingSlot

                NIcon {
                  anchors.centerIn: parent
                  visible: !actionRow.modelData.busy
                  icon: actionRow.isConfirming ? "alert-triangle" : (actionRow.modelData.icon || "dots")
                  pointSize: Style.fontSizeL
                  color: actionRow.foreground
                }

                NBusyIndicator {
                  anchors.centerIn: parent
                  visible: !!actionRow.modelData.busy
                  running: visible
                  size: Math.round(Style.fontSizeL * 1.3 * Style.uiScaleRatio)
                  strokeWidth: Style.borderM
                  color: Color.mPrimary
                }
              }

              NText {
                Layout.fillWidth: true
                text: {
                  if (actionRow.isConfirming)
                    return I18n.tr("launcher.app-actions.confirm-uninstall", {
                                     "value": root.shownItem?.name || ""
                                   });
                  return actionRow.modelData.label || "";
                }
                pointSize: Style.fontSizeS
                font.weight: actionRow.isConfirming ? Style.fontWeightSemiBold : Style.fontWeightMedium
                color: actionRow.foreground
                elide: Text.ElideRight
              }

              // Supporting text (target version, package backend, …)
              NText {
                text: actionRow.modelData.description || ""
                visible: !actionRow.isConfirming && text !== ""
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                Layout.maximumWidth: Math.round(actionRow.width * 0.45)
              }

              // Explicit two-way decision for destructive actions: the previous
              // "click again to confirm" had no visible way out.
              Rectangle {
                visible: actionRow.isConfirming
                Layout.preferredWidth: cancelLabel.implicitWidth + Style.margin2M
                Layout.preferredHeight: Math.round(root.rowHeight * 0.64)
                Layout.alignment: Qt.AlignVCenter
                radius: height * 0.5
                color: cancelMouse.containsMouse ? Qt.alpha(Color.mOnErrorContainer, 0.14) : "transparent"
                border.width: Style.borderS
                border.color: Qt.alpha(Color.mOnErrorContainer, 0.4)

                NText {
                  id: cancelLabel
                  anchors.centerIn: parent
                  text: I18n.tr("common.cancel")
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightSemiBold
                  color: Color.mOnErrorContainer
                }

                MouseArea {
                  id: cancelMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.launcher)
                      root.launcher.cancelAppPanelConfirm();
                  }
                }
              }

              Rectangle {
                visible: actionRow.isConfirming
                Layout.preferredWidth: confirmLabel.implicitWidth + Style.margin2M
                Layout.preferredHeight: Math.round(root.rowHeight * 0.64)
                Layout.alignment: Qt.AlignVCenter
                radius: height * 0.5
                color: confirmMouse.containsMouse ? Color.mError : Qt.alpha(Color.mError, 0.85)

                NText {
                  id: confirmLabel
                  anchors.centerIn: parent
                  text: I18n.tr("common.confirm")
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightSemiBold
                  color: Color.mOnError
                }

                MouseArea {
                  id: confirmMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.launcher)
                      root.launcher.activateAppPanelAction(actionRow.index);
                  }
                }
              }
            }
          }
        }

        // Failure feedback from the package manager
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginXS
          Layout.rightMargin: Style.marginXS
          Layout.topMargin: Style.marginXS
          Layout.preferredHeight: errorRow.implicitHeight + Style.margin2S
          visible: root.errorText !== ""
          radius: Style.radiusS
          color: Color.mErrorContainer

          RowLayout {
            id: errorRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.marginS
            anchors.rightMargin: Style.marginS
            spacing: Style.marginS

            NIcon {
              icon: "alert-circle"
              pointSize: Style.fontSizeM
              color: Color.mError
              Layout.alignment: Qt.AlignTop
            }

            NText {
              Layout.fillWidth: true
              text: root.errorText
              pointSize: Style.fontSizeXS
              color: Color.mOnErrorContainer
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
            }
          }
        }
      }

      // ---------------------------------------------------------------
      // Properties — two-line list items instead of "label: value" strings, so
      // long ids and commands stay readable.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginXS
        Layout.rightMargin: Style.marginXS
        Layout.bottomMargin: Style.marginS
        visible: root.showingProperties
        spacing: Style.marginXS

        // No app name here on purpose: the entry the panel is attached to sits
        // directly above and already carries the name and description.

        Repeater {
          model: root.showingProperties ? root.propertyRows : []

          delegate: RowLayout {
            required property var modelData

            Layout.fillWidth: true
            // Matches the action rows' leading column, so switching views keeps
            // the same left rhythm.
            Layout.leftMargin: Style.marginXS + Style.marginS
            Layout.rightMargin: Style.marginS
            spacing: Style.marginS

            Item {
              Layout.preferredWidth: root.leadingSlot
              Layout.preferredHeight: root.leadingSlot
              Layout.alignment: Qt.AlignVCenter

              NIcon {
                anchors.centerIn: parent
                icon: modelData.icon
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              NText {
                Layout.fillWidth: true
                text: modelData.label
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
              }

              NText {
                Layout.fillWidth: true
                text: modelData.value
                pointSize: Style.fontSizeS
                color: Color.mOnSurface
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // Properties model
  readonly property string commandText: {
    const app = shownApp;
    if (!app)
      return "";
    if (Array.isArray(app.command))
      return app.command.join(" ");
    if (app.command && app.command.length !== undefined)
      return Array.from(app.command).join(" ");
    return String(app.exec || "");
  }

  readonly property string categoriesText: {
    const app = shownApp;
    if (!app || !provider || !provider.getAppCategories)
      return "";
    return provider.getAppCategories(app).join(", ");
  }

  readonly property var packageInfo: {
    const app = shownApp;
    if (!app || !provider || !provider.getPackageForApp)
      return null;
    return provider.getPackageForApp(app);
  }

  readonly property string backendText: {
    const info = packageInfo;
    if (!info)
      return "";
    return `${info.name} · ${I18n.tr(`launcher.app-actions.backend-${info.type}`)}`;
  }

  readonly property var propertyRows: {
    const rows = [];
    const appId = shownApp?.id || shownItem?.appId || "";
    if (appId !== "")
      rows.push({
                  "icon": "id-badge",
                  "label": I18n.tr("launcher.app-properties.app-id"),
                  "value": appId
                });
    if (commandText !== "")
      rows.push({
                  "icon": "terminal-2",
                  "label": I18n.tr("launcher.app-properties.command"),
                  "value": commandText
                });
    if (categoriesText !== "")
      rows.push({
                  "icon": "category",
                  "label": I18n.tr("launcher.app-properties.categories"),
                  "value": categoriesText
                });
    if (backendText !== "")
      rows.push({
                  "icon": "package",
                  "label": I18n.tr("launcher.app-properties.backend"),
                  "value": backendText
                });
    if (packageInfo && packageInfo.version)
      rows.push({
                  "icon": "tag",
                  "label": I18n.tr("launcher.app-properties.version"),
                  "value": String(packageInfo.version)
                });
    return rows;
  }

  function requestClose() {
    if (launcher && launcher.closeAppPanel)
      launcher.closeAppPanel();
  }
}
