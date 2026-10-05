import QtQuick
import qs.Commons

QtObject {
  readonly property string mode: Settings.data.appLauncher.density
  readonly property bool compact: mode === "compact"
  readonly property bool comfortable: mode === "comfortable"
  readonly property real spacingRatio: compact ? 0.75 : (comfortable ? 1.25 : 1)
  readonly property real gapXS: Math.round(Style.marginXS * spacingRatio)
  readonly property real gapS: Math.round(Style.marginS * spacingRatio)
  readonly property real gapM: Math.round(Style.marginM * spacingRatio)
  readonly property real gapL: Math.round(Style.marginL * spacingRatio)
  readonly property real padding: gapL
  readonly property real outerPadding: gapM
  readonly property real searchHeight: Math.round((compact ? 44 : (comfortable ? 56 : 50)) * Style.uiScaleRatio)
  readonly property real pillHeight: Math.round((compact ? 32 : (comfortable ? 42 : 38)) * Style.uiScaleRatio)
  readonly property real allAppsHeight: Math.round((compact ? 56 : (comfortable ? 72 : 64)) * Style.uiScaleRatio)
  readonly property real pinnedHeight: Math.round((compact ? 72 : (comfortable ? 88 : 80)) * Style.uiScaleRatio)
  readonly property real recentHeight: Math.round((compact ? 34 : (comfortable ? 44 : 38)) * Style.uiScaleRatio)
  readonly property real folderGap: gapM
  readonly property real gridCell: Math.round((compact ? 64 : (comfortable ? 80 : 72)) * Style.uiScaleRatio)
  readonly property real folderAppHeight: Math.round((compact ? 76 : (comfortable ? 96 : 86)) * Style.uiScaleRatio)
}
