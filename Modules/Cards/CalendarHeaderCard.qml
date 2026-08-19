import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Widgets

// Calendar header with date, month/year, location, and clock
Rectangle {
  id: root
  Layout.fillWidth: true
  Layout.minimumHeight: (60 * Style.uiScaleRatio) + Style.spaceS * 2
  Layout.preferredHeight: (60 * Style.uiScaleRatio) + Style.spaceS * 2
  implicitHeight: (60 * Style.uiScaleRatio) + Style.spaceS * 2
  radius: Style.radiusCard
  color: Color.mPrimary

  // Internal state
  readonly property var now: Time.now
  readonly property bool weatherReady: Settings.data.location.weatherEnabled && (LocationService.data.weather !== null)

  // Expose current month/year for potential synchronization with CalendarMonthCard
  readonly property int currentMonth: now.getMonth()
  readonly property int currentYear: now.getFullYear()

  ColumnLayout {
    id: capsuleColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.topMargin: Style.spaceS
    anchors.bottomMargin: Style.spaceS
    anchors.rightMargin: clockLoader.width + Style.spaceXXL
    anchors.leftMargin: Style.spaceXL
    spacing: 0

    // Combined layout for date, month year, location and time-zone
    RowLayout {
      Layout.fillWidth: true
      height: 60 * Style.uiScaleRatio
      clip: true
      spacing: Style.spaceXS

      // Today day number
      NText {
        Layout.preferredWidth: implicitWidth
        elide: Text.ElideNone
        clip: true
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        text: root.now.getDate()
        pointSize: Style.fontSizeDisplaySmall
        font.weight: Style.fontWeightBold
        color: Color.mOnPrimary
      }

      // Month, year, location
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        Layout.bottomMargin: Style.spaceXXS
        Layout.topMargin: -Style.spaceXXS
        spacing: -Style.spaceXXS

        RowLayout {
          spacing: Style.spaceXS

          NText {
            text: I18n.locale.monthName(root.currentMonth, Locale.LongFormat).toUpperCase()
            pointSize: Style.fontSizeTitleMedium
            font.weight: Style.fontWeightBold
            color: Color.mOnPrimary
            Layout.alignment: Qt.AlignBaseline
            elide: Text.ElideRight
          }

          NText {
            text: `${root.currentYear}`
            pointSize: Style.fontSizeLabelLarge
            font.weight: Style.fontWeightBold
            color: Qt.alpha(Color.mOnPrimary, 0.7)
            Layout.alignment: Qt.AlignBaseline
          }
        }

        RowLayout {
          spacing: 0

          NText {
            text: {
              if (!Settings.data.location.weatherEnabled)
                return "";
              if (!LocationService.locationConfigured)
                return I18n.tr("common.weather-no-location");
              if (!root.weatherReady)
                return I18n.tr("common.weather-loading");
              if (Settings.data.location.hideWeatherCityName)
                return "";
              const chunks = Settings.data.location.name.split(",");
              return chunks[0];
            }
            pointSize: Style.fontSizeLabelLarge
            color: Color.mOnPrimary
            Layout.maximumWidth: 150
            elide: Text.ElideRight
          }

          NText {
            text: root.weatherReady && !Settings.data.location.hideWeatherTimezone ? `${Settings.data.location.hideWeatherCityName ? "" : " "}(${LocationService.data.weather.timezone_abbreviation})` : ""
            pointSize: Style.fontSizeLabelSmall
            color: Qt.alpha(Color.mOnPrimary, 0.7)
          }
        }
      }

      // Spacer
      Item {
        Layout.fillWidth: true
      }
    }
  }

  // Analog/Digital clock
  NClock {
    id: clockLoader
    anchors.right: parent.right
    anchors.rightMargin: Style.spaceXL
    anchors.verticalCenter: parent.verticalCenter
    clockStyle: Settings.data.location.analogClockInCalendar ? "analog" : "digital"
    progressColor: Color.mOnPrimary
    Layout.alignment: Qt.AlignVCenter
    now: root.now
  }
}
