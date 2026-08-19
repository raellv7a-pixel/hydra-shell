import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Location
DashboardCard {
  id: weatherDetailsCard

  styleKey: "calendar"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"
  clip: true

  readonly property bool weatherReady: Settings.data.location.weatherEnabled && LocationService.data.weather !== null
  readonly property var weatherData: weatherReady ? LocationService.data.weather : null
  readonly property var currentWeather: weatherReady ? weatherData.current_weather : null
  readonly property var currentDetails: weatherReady ? weatherData.current : null
  readonly property var dailyWeather: weatherReady ? weatherData.daily : null

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("weather")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NText {
        text: weatherReady ? panelRoot.tr("live") : panelRoot.tr("idle")
        pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: weatherReady ? Color.mPrimary : Color.mOnSurfaceVariant
      }
    }

    WeatherCard {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(218 * panelRoot.panelUnit)
      forecastDays: 5
      showLocation: true
      radius: Style.radiusS
      color: panelRoot.m3SurfaceContainerHigh
      border.color: "transparent"
    }

    NText {
      visible: !weatherReady
      Layout.fillWidth: true
      Layout.fillHeight: true
      text: panelRoot.tr("noWeather")
      color: Color.mOnSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    GridLayout {
      visible: weatherReady
      Layout.fillWidth: true
      columns: 2
      columnSpacing: Style.marginM
      rowSpacing: Style.marginM

      WeatherInfoTile {
        panelRoot: weatherDetailsCard.panelRoot
        Layout.fillWidth: true
        iconName: "temperature"
        titleText: panelRoot.tr("temperature")
        valueText: panelRoot.weatherTemperature(currentWeather?.temperature)
      }

      WeatherInfoTile {
        panelRoot: weatherDetailsCard.panelRoot
        Layout.fillWidth: true
        iconName: "wind"
        titleText: panelRoot.tr("wind")
        valueText: Math.round(Number(currentWeather?.windspeed || 0)) + " km/h"
      }

      WeatherInfoTile {
        panelRoot: weatherDetailsCard.panelRoot
        Layout.fillWidth: true
        iconName: "droplet"
        titleText: panelRoot.tr("humidity")
        valueText: currentDetails?.relativehumidity_2m !== undefined ? Math.round(Number(currentDetails.relativehumidity_2m)) + "%" : "--"
      }

      WeatherInfoTile {
        panelRoot: weatherDetailsCard.panelRoot
        Layout.fillWidth: true
        iconName: "clock"
        titleText: panelRoot.tr("timezone")
        valueText: weatherData?.timezone_abbreviation || "--"
      }

      WeatherInfoTile {
        panelRoot: weatherDetailsCard.panelRoot
        Layout.fillWidth: true
        iconName: "sunrise"
        titleText: panelRoot.tr("sunrise")
        valueText: panelRoot.weatherTimeLabel(dailyWeather?.sunrise?.[0])
      }

      WeatherInfoTile {
        panelRoot: weatherDetailsCard.panelRoot
        Layout.fillWidth: true
        iconName: "sunset"
        titleText: panelRoot.tr("sunset")
        valueText: panelRoot.weatherTimeLabel(dailyWeather?.sunset?.[0])
      }
    }

    DashboardCard {
      panelRoot: weatherDetailsCard.panelRoot
      visible: weatherReady
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          text: panelRoot.tr("forecast")
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
        }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: forecastColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: forecastColumn
            width: parent.width
            spacing: Style.marginS

            Repeater {
              model: dailyWeather?.time ? Math.min(7, dailyWeather.time.length) : 0

              WeatherForecastRow {
                panelRoot: weatherDetailsCard.panelRoot
                Layout.fillWidth: true
                dayIndex: index
                dailyData: dailyWeather
              }
            }
          }
        }
      }
    }
  }
}
