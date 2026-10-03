import QtQuick
import QtQml.Models
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

Item {
  id: root
  required property var trayItem
  property var menuPath: []
  readonly property var currentMenu: menuPath.length ? menuPath[menuPath.length - 1] : trayItem?.menu ?? null
  signal back
  signal submenu(var entry)
  signal activated
  signal pinToggled
  property bool pinned: false
  property bool canPin: false

  property int openerRevision: 0
  // Keep each ancestor menu open while showing a submenu. Replacing the
  // opener's menu destroys its child QsMenuEntry objects and invalidates
  // menuPath before the submenu can load.
  Instantiator {
    id: openers
    model: root.menuPath.length + 1
    delegate: QsMenuOpener {
      required property int index
      menu: index === 0 ? root.trayItem?.menu ?? null : root.menuPath[index - 1]
    }
    onObjectAdded: root.openerRevision++
    onObjectRemoved: root.openerRevision++
  }

  readonly property var currentOpener: { void openerRevision; return openers.objectAt(menuPath.length); }
  readonly property var menuEntries: (currentOpener?.children && currentOpener.children.values) ? [...currentOpener.children.values] : []
  readonly property bool hasPinButton: root.canPin && root.menuPath.length === 0

  // Bounded width clamp values
  readonly property real minMenuWidth: Math.round(200 * Style.uiScaleRatio)
  readonly property real maxMenuWidth: Math.round(360 * Style.uiScaleRatio)

  // Bounded height clamp values
  readonly property real minMenuHeight: Math.round(120 * Style.uiScaleRatio)
  readonly property real screenMaxHeight: (root.Window.window?.screen?.height || 800) * 0.7

  // Measuring text for action rows
  NText {
    id: textMeasure
    visible: false
    pointSize: Style.fontSizeM
    wrapMode: Text.NoWrap
    elide: Text.ElideNone
  }
  FontMetrics { id: actionMetrics; font: textMeasure.font }
  // Measuring text for header title
  NText {
    id: headerMeasure
    visible: false
    pointSize: Style.fontSizeXL
    font.weight: Style.fontWeightSemiBold
    wrapMode: Text.NoWrap
    elide: Text.ElideNone
  }
  FontMetrics { id: headerMetrics; font: headerMeasure.font }
  // Measuring text for pin button
  NText {
    id: pinMeasure
    visible: false
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightSemiBold
    wrapMode: Text.NoWrap
    elide: Text.ElideNone
  }
  FontMetrics { id: pinMetrics; font: pinMeasure.font }

  // Calculate content-driven width needed across header, action items, and pin footer
  readonly property real naturalContentWidth: {
    let maxW = 0;

    // 1. Measure header width
    const headerTitle = root.menuPath.length ? (root.currentMenu?.text || root.trayItem?.tooltipTitle || root.trayItem?.title || root.trayItem?.id || "") : (root.trayItem?.tooltipTitle || root.trayItem?.title || root.trayItem?.id || "");
    const backBtnWidth = Math.round(30 * Style.uiScaleRatio);
    const appIconWidth = Math.round(Style.baseWidgetSize * 0.65);
    const headerW = backBtnWidth + Style.marginS + appIconWidth + Style.marginS + headerMetrics.advanceWidth(headerTitle);
    if (headerW > maxW)
      maxW = headerW;

    // 2. Measure widest action row
    const entries = menuEntries;
    const actionRowPadding = Style.marginS * 2; // left + right margins inside row
    for (let i = 0; i < entries.length; i++) {
      const item = entries[i];
      if (!item || item.isSeparator)
        continue;

      let rowW = actionRowPadding;

      // Indicator (check / radio)
      if ((item.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None) {
        rowW += Style.fontSizeS + Style.marginS;
      }

      // Action icon
      if (item.icon) {
        rowW += Style.fontSizeM + Style.marginS;
      }

      // Text label
      const cleanText = (item.text || "").replace(/[\n\r]+/g, " ");
      rowW += actionMetrics.advanceWidth(cleanText);

      // Submenu chevron
      if (item.hasChildren) {
        rowW += Style.marginS + Style.fontSizeS;
      }

      if (rowW > maxW)
        maxW = rowW;
    }

    // 3. Measure pin button if visible
    if (hasPinButton) {
      const pinText = root.pinned ? I18n.tr("panels.bar.tray-unpin-application") : I18n.tr("panels.bar.tray-pin-application");
      // NButton: contentRow.implicitWidth (icon + spacing + text) + (root.fontSize * 2) + border
      const pinW = Style.fontSizeL + Style.marginS + pinMetrics.advanceWidth(pinText) + (Style.fontSizeM * 2) + (Style.borderS * 2);
      if (pinW > maxW)
        maxW = pinW;
    }

    // Add outer margins (Style.marginM on left and right)
    return maxW + (Style.marginM * 2);
  }

  // Calculate natural height for all action rows and separators
  readonly property real actionItemsHeight: {
    const entries = menuEntries;
    if (entries.length === 0)
      return 0;

    let totalH = 0;
    const rowSpacing = Style.marginXXS;
    for (let i = 0; i < entries.length; i++) {
      const item = entries[i];
      if (item?.isSeparator) {
        totalH += Style.marginM;
      } else {
        totalH += Math.max(Math.round(30 * Style.uiScaleRatio), actionMetrics.height + Style.marginS);
      }
      if (i > 0)
        totalH += rowSpacing;
    }
    return totalH;
  }

  readonly property real headerHeight: Math.max(Math.round(30 * Style.uiScaleRatio), Style.baseWidgetSize * 0.65)
  readonly property real pinButtonHeight: hasPinButton ? Math.round(34 * Style.uiScaleRatio) : 0
  readonly property real totalNaturalHeight: {
    let h = (Style.marginM * 2) + headerHeight + Style.marginS + actionItemsHeight;
    if (hasPinButton)
      h += Style.marginS + pinButtonHeight;
    return h;
  }

  // Content-driven implicit dimensions clamped within reasonable bounds
  implicitWidth: Math.max(minMenuWidth, Math.min(maxMenuWidth, Math.ceil(naturalContentWidth)))
  implicitHeight: Math.max(minMenuHeight, Math.min(screenMaxHeight, Math.ceil(totalNaturalHeight)))

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: root.headerHeight
      spacing: Style.marginS

      NIconButton {
        icon: "chevron-left"
        tooltipText: I18n.tr("common.back")
        baseSize: Math.round(30 * Style.uiScaleRatio)
        colorBg: "transparent"
        colorBgHover: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurface
        colorFgHover: Color.mOnSurface
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: root.back()
      }

      IconImage {
        Layout.preferredWidth: Style.baseWidgetSize * 0.65
        Layout.preferredHeight: Layout.preferredWidth
        source: root.trayItem?.icon ?? ""
      }

      NText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.menuPath.length ? (root.currentMenu?.text || root.trayItem?.tooltipTitle || root.trayItem?.title || root.trayItem?.id || "") : (root.trayItem?.tooltipTitle || root.trayItem?.title || root.trayItem?.id || "")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }
    }

    NScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false
      showGradientMasks: false

      ColumnLayout {
        width: parent.width
        spacing: Style.marginXXS

        Repeater {
          model: root.menuEntries

          delegate: Item {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData?.isSeparator ? Style.marginM : Math.max(Math.round(30 * Style.uiScaleRatio), label.implicitHeight + Style.marginS)

            NDivider {
              anchors.centerIn: parent
              width: parent.width - Style.margin2S
              visible: entry.modelData?.isSeparator ?? false
            }

            Rectangle {
              anchors.fill: parent
              radius: Style.radiusS
              visible: !(entry.modelData?.isSeparator ?? false)
              color: {
                if (!entry.modelData?.enabled)
                  return "transparent";
                return pointer.containsMouse ? Color.mSurfaceContainerHighest : "transparent";
              }

              Behavior on color {
                ColorAnimation {
                  duration: pointer.containsMouse ? Style.hoverEnterDuration : Style.hoverLeaveDuration
                  easing.type: Easing.OutCubic
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                spacing: Style.marginS

                NIcon {
                  visible: (entry.modelData?.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None
                  icon: entry.modelData?.buttonType === QsMenuButtonType.RadioButton ? ((entry.modelData?.checkState === Qt.Checked || entry.modelData?.checked) ? "circle-dot" : "circle") : ((entry.modelData?.checkState === Qt.Checked || entry.modelData?.checked) ? "checkbox" : "square")
                  color: Color.mPrimary
                  pointSize: Style.fontSizeS
                  Layout.alignment: Qt.AlignVCenter
                }

                IconImage {
                  visible: !!entry.modelData?.icon
                  source: entry.modelData?.icon ?? ""
                  Layout.preferredWidth: Style.fontSizeM
                  Layout.preferredHeight: Style.fontSizeM
                  Layout.alignment: Qt.AlignVCenter
                }

                NText {
                  id: label
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: (entry.modelData?.text || "").replace(/[\n\r]+/g, " ")
                  color: entry.modelData?.enabled ? Color.mOnSurface : Color.mOnSurfaceVariant
                  elide: Text.ElideRight
                  pointSize: Style.fontSizeM
                }

                NIcon {
                  visible: entry.modelData?.hasChildren ?? false
                  icon: "chevron-right"
                  color: Color.mOnSurfaceVariant
                  pointSize: Style.fontSizeS
                  Layout.alignment: Qt.AlignVCenter
                }
              }

              MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true
                enabled: (entry.modelData?.enabled ?? false) && !(entry.modelData?.isSeparator ?? false)
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                  if (entry.modelData.hasChildren)
                    root.submenu(entry.modelData);
                  else {
                    entry.modelData.triggered();
                    root.activated();
                  }
                }
              }
            }
          }
        }
      }
    }

    NButton {
      visible: root.hasPinButton
      Layout.fillWidth: true
      Layout.preferredHeight: root.pinButtonHeight
      text: root.pinned ? I18n.tr("panels.bar.tray-unpin-application") : I18n.tr("panels.bar.tray-pin-application")
      icon: root.pinned ? "unpin" : "pin"
      backgroundColor: Color.mSecondaryContainer
      textColor: Color.mOnSecondaryContainer
      hoverColor: Color.mSurfaceContainerHighest
      textHoverColor: Color.mOnSurface
      buttonRadius: Style.radiusS
      onClicked: root.pinToggled()
    }
  }
}
