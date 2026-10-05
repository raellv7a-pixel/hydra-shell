import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import "../../../Helpers/ColorsConvert.js" as ColorsConvert
import qs.Commons
import qs.Services.Power
import qs.Services.System
import qs.Widgets

Item {
  id: root
  required property var launcher
  property alias currentIndex: pages.currentIndex
  readonly property bool presented: visible && launcher.isOpen
  readonly property bool contextEnabled: Settings.data.appLauncher.heroShowContext
  readonly property bool surfaceIsLight: ColorsConvert.isLightColor(Color.mSurface.toString())
  readonly property color lightTone: surfaceIsLight ? Color.mSurface : Color.mOnSurface
  readonly property color darkTone: surfaceIsLight ? Color.mOnSurface : Color.mSurface
  readonly property bool lightText: Settings.data.appLauncher.heroTextContrast !== "dark"
  readonly property color foreground: lightText ? lightTone : darkTone
  readonly property string registrationId: "launcher-hero-" + (launcher.screen?.name || "default")
  readonly property bool statsPresented: presented && contextEnabled
  property bool automaticChange: false
  onStatsPresentedChanged: {
    if (statsPresented) SystemStatService.registerComponent(registrationId);
    else SystemStatService.unregisterComponent(registrationId);
  }
  onPresentedChanged: if (!presented) { cooldown.stop(); wheelCooldown.stop(); }
  onContextEnabledChanged: if (!contextEnabled) pages.setCurrentIndex(0)
  Component.onDestruction: SystemStatService.unregisterComponent(registrationId)
  function reset() { pages.setCurrentIndex(0); }
  function handleWheel(event) {
    if (!presented || pages.count < 2 || Settings.data.appLauncher.ignoreMouseInput) return false;
    const x = event.pixelDelta.x || event.angleDelta.x;
    const y = event.pixelDelta.y || event.angleDelta.y;
    const delta = Math.abs(x) > Math.abs(y) ? x : y;
    if (!delta) return false;
    if (wheelCooldown.running) return true;
    const next = Math.max(0, Math.min(pages.count - 1, pages.currentIndex + (delta < 0 ? 1 : -1)));
    if (next === pages.currentIndex) return false;
    pages.setCurrentIndex(next);
    wheelCooldown.restart();
    return true;
  }
  Timer { id: wheelCooldown; interval: 220 }

  Timer {
    id: cooldown
    interval: 40000
  }
  Timer {
    interval: 20000
    repeat: true
    running: root.presented && pages.count > 1 && Settings.data.appLauncher.heroAutoRotate && !Settings.data.general.animationDisabled && !PowerProfileService.hydraPerformanceMode && !hover.hovered && !cooldown.running && !pages.contentItem.moving
    onTriggered: {
      root.automaticChange = true;
      pages.setCurrentIndex((pages.currentIndex + 1) % pages.count);
      root.automaticChange = false;
    }
  }
  HoverHandler { id: hover }
  Connections {
    target: pages.contentItem
    function onMovementStarted() { if (!root.automaticChange && root.presented) cooldown.restart(); }
  }
  NDropShadow {
    anchors.fill: surface
    source: surface
    autoPaddingEnabled: true
    shadowColor: Color.mShadow
    shadowOpacity: Style.shadowOpacity * Style.opacityLight
    shadowHorizontalOffset: 0
    shadowVerticalOffset: Style.marginXXS
  }
  NBox {
    id: surface
    anchors.fill: parent
    radius: Style.radiusL
    color: Color.mSurfaceContainerHigh
    forceOpaque: true
    border.width: 0
    SwipeView {
      id: pages
      anchors.fill: parent
      clip: true
      interactive: !Settings.data.appLauncher.ignoreMouseInput
      onCurrentIndexChanged: if (!root.automaticChange && root.presented) cooldown.restart()
      contentItem: ListView {
        model: pages.contentModel
        currentIndex: pages.currentIndex
        orientation: ListView.Horizontal
        interactive: pages.interactive
        snapMode: ListView.SnapOneItem
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightMoveDuration: Settings.data.general.animationDisabled ? 0 : Style.animationNormal
      }
      Item {
        Item {
          id: coverSource
          anchors.fill: parent
          NImageRounded {
            anchors.fill: parent
            imagePath: root.launcher.profileWallpaperPath
            radius: 0
          }
        }
        ShaderEffectSource {
          id: coverTexture
          anchors.fill: coverSource
          sourceItem: coverSource
          hideSource: true
          visible: false
          live: root.presented
        }
        Rectangle {
          id: coverMask
          anchors.fill: parent
          radius: Style.radiusL
          color: Color.mOnSurface
          visible: false
          layer.enabled: true
        }
        MultiEffect {
          anchors.fill: parent
          source: coverTexture
          autoPaddingEnabled: false
          maskEnabled: true
          maskSource: coverMask
          blurEnabled: root.presented && Settings.data.appLauncher.coverBlurEnabled && !PowerProfileService.hydraPerformanceMode
          blur: Math.max(0, Math.min(1, Settings.data.appLauncher.heroBlurIntensity))
          blurMax: 32
        }
        // Retain the authored overlay preference as image dimming, not a light veil.
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusL
          color: Qt.alpha(Color.mShadow, Settings.data.appLauncher.coverOverlay * 0.20)
        }
        RowLayout {
          id: greeting
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.leftMargin: Style.margin2XL
          anchors.bottomMargin: Style.margin2XL
          spacing: Style.marginM
          NIcon { icon: Time.now.getHours() < 18 ? "sun" : "moon"; pointSize: Style.fontSizeXXXL; color: root.foreground }
          ColumnLayout {
            spacing: Style.marginXXS
            NText { text: I18n.tr(Time.now.getHours() < 12 ? "launcher-home.morning" : (Time.now.getHours() < 18 ? "launcher-home.afternoon" : "launcher-home.evening")); pointSize: Style.fontSizeXXL; font.weight: Style.fontWeightBold; color: root.foreground }
            NText { text: I18n.tr("launcher-home.hero-subtitle"); pointSize: Style.fontSizeM; color: root.foreground }
          }
        }
      }
    }
    Loader {
      active: root.contextEnabled
      sourceComponent: contextPage
      onLoaded: pages.addItem(item)
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.marginS
      spacing: Style.marginXS
      Repeater {
        model: pages.count
        LauncherHomeButton {
          required property int index
          launcher: root.launcher
          text: I18n.tr("launcher-home.hero-page", { count: index + 1 })
          Accessible.selected: pages.currentIndex === index
          width: Math.round((pages.currentIndex === index ? 20 : 10) * Style.uiScaleRatio)
          height: Math.round(10 * Style.uiScaleRatio)
          padding: 0
          cornerRadius: height / 2
          surface: pages.currentIndex === index ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.6)
          contentItem: Item {}
          onClicked: pages.setCurrentIndex(index)
        }
      }
    }
    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      enabled: root.presented && pages.count > 1 && !Settings.data.appLauncher.ignoreMouseInput
      blocking: false
      onWheel: event => {
        blocking = root.handleWheel(event);
        event.accepted = blocking;
      }
    }
  }
  Component {
    id: contextPage
    Item {
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.margin2XL
        spacing: Style.marginS
        NText { text: Time.now.toLocaleDateString(I18n.locale, Locale.LongFormat); pointSize: Style.fontSizeM; color: Color.mOnSurfaceVariant }
        NText { text: Time.now.toLocaleTimeString(I18n.locale, Locale.ShortFormat); pointSize: Style.fontSizeXXXL; font.weight: Style.fontWeightBold }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginL
          NIcon { icon: "cpu"; color: Color.mPrimary }
          NText { text: I18n.tr("launcher-home.cpu", { value: Math.round(SystemStatService.cpuUsage) }); pointSize: Style.fontSizeS }
          NIcon { icon: "server"; color: Color.mPrimary }
          NText { text: I18n.tr("launcher-home.memory", { value: Math.round(SystemStatService.memPercent) }); pointSize: Style.fontSizeS }
          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
