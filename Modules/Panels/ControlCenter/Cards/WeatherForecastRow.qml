import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Location
import qs.Widgets

DashboardCard {
  id: forecastRow

  property int dayIndex: 0
  property var dailyData: null

  Layout.preferredHeight: Math.round(54 * panelRoot.panelUnit)
  color: Color.mSurfaceContainerHighest
  radius: Style.radiusS

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    NText {
      Layout.preferredWidth: Math.round(48 * panelRoot.panelUnit)
      text: panelRoot.weatherDayLabel(forecastRow.dailyData?.time?.[forecastRow.dayIndex])
      color: Color.mOnSurface
      font.weight: Style.fontWeightSemiBold
    }

    NIcon {
      icon: LocationService.weatherSymbolFromCode(forecastRow.dailyData?.weathercode?.[forecastRow.dayIndex] || 0)
      pointSize: Style.fontSizeXL
      color: Color.mPrimary
    }

    Item {
      Layout.fillWidth: true
    }

    NText {
      text: panelRoot.weatherTemperature(forecastRow.dailyData?.temperature_2m_max?.[forecastRow.dayIndex])
      color: Color.mOnSurface
      font.weight: Style.fontWeightSemiBold
    }

    NText {
      text: panelRoot.weatherTemperature(forecastRow.dailyData?.temperature_2m_min?.[forecastRow.dayIndex])
      color: Color.mOnSurfaceVariant
    }
  }
}
