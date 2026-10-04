pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root
  readonly property var settings: UmbrielSettingsStore
  Layout.fillWidth: true
  spacing: Style.marginXL
  enabled: settings.loaded && !settings.externallyOwned && !settings.busy

  GridLayout {
    Layout.fillWidth: true
    columns: root.width >= Style.sliderWidth * 4 * Style.uiScaleRatio ? 2 : 1
    columnSpacing: Style.marginL
    rowSpacing: Style.marginL

    Repeater {
      model: [
        { key: "top_left", title: I18n.tr("panels.umbriel.corner-top-left"), icon: "corner-up-left" },
        { key: "top_right", title: I18n.tr("panels.umbriel.corner-top-right"), icon: "corner-up-right" },
        { key: "bottom_left", title: I18n.tr("panels.umbriel.corner-bottom-left"), icon: "corner-down-left" },
        { key: "bottom_right", title: I18n.tr("panels.umbriel.corner-bottom-right"), icon: "corner-down-right" }
      ]
      delegate: Rectangle {
        id: cornerBlock
        required property var modelData
        readonly property var corner: root.settings.draft.hot_corners?.[modelData.key] || ({})
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        implicitHeight: controls.implicitHeight + Style.margin2XL
        radius: Style.radiusM
        color: corner.enabled ? Color.mSurfaceContainerHigh : Color.mSurfaceContainerLow

        Behavior on color {
          enabled: !Color.isTransitioning
          ColorAnimation { duration: Style.animationFast }
        }

        ColumnLayout {
          id: controls
          anchors.fill: parent
          anchors.margins: Style.marginXL
          spacing: Style.marginL

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM
            Rectangle {
              Layout.preferredWidth: Style.baseWidgetSize * Style.uiScaleRatio
              Layout.preferredHeight: Layout.preferredWidth
              radius: Style.iRadiusM
              color: cornerBlock.corner.enabled ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
              NIcon {
                anchors.centerIn: parent
                icon: cornerBlock.modelData.icon
                pointSize: Style.fontSizeL
                color: cornerBlock.corner.enabled ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
              }
            }
            NText {
              Layout.fillWidth: true
              text: cornerBlock.modelData.title
              font.weight: Style.fontWeightSemiBold
              pointSize: Style.fontSizeL
              color: Color.mOnSurface
            }
            NToggle {
              Layout.fillWidth: false
              label: ""
              Accessible.name: cornerBlock.modelData.title + " · " + I18n.tr("panels.umbriel.hot-enabled")
              checked: !!cornerBlock.corner.enabled
              onToggled: checked => root.settings.updateCorner(cornerBlock.modelData.key, "enabled", checked)
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginL
            opacity: cornerBlock.corner.enabled ? 1 : Style.opacityHeavy
            NValueSlider {
              label: I18n.tr("panels.umbriel.hot-delay")
              description: I18n.tr("panels.umbriel.hot-delay-description")
              from: 0; to: 10000; stepSize: 50
              value: cornerBlock.corner.delay_ms ?? 500
              text: String(Math.round(value))
              onMoved: value => root.settings.updateCorner(cornerBlock.modelData.key, "delay_ms", Math.round(value))
            }
            UmbrielActionPicker {
              label: I18n.tr("panels.umbriel.hot-action")
              action: cornerBlock.corner.action || ""
              onSelected: action => root.settings.updateCorner(cornerBlock.modelData.key, "action", action)
            }
          }
        }
      }
    }
  }
}
