import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  Layout.fillWidth: true
  Layout.fillHeight: true

  function dtr(key) {
    return I18n.tr("panels.dashboard." + key);
  }

  NHeader {
    label: root.dtr("settingsAudioVisualizers")
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.dtr("settingsMediaVisualizer")
    description: root.dtr("settingsMediaVisualizerDesc")
    currentKey: Settings.data.controlCenter.mediaVisualizerEffect
    model: [
      {
        "key": "none",
        "name": root.dtr("visualizerNone")
      },
      {
        "key": "bars",
        "name": root.dtr("visualizerBars")
      },
      {
        "key": "mirror",
        "name": root.dtr("settingsVisualizerMirror")
      },
      {
        "key": "wave",
        "name": root.dtr("visualizerWave")
      },
      {
        "key": "ribbon",
        "name": root.dtr("settingsVisualizerRibbon")
      },
      {
        "key": "shock",
        "name": root.dtr("visualizerShock")
      },
      {
        "key": "pulse",
        "name": root.dtr("visualizerPulse")
      },
      {
        "key": "nebula",
        "name": root.dtr("visualizerNebula")
      },
      {
        "key": "aurora",
        "name": root.dtr("visualizerAurora")
      },
      {
        "key": "constellation",
        "name": root.dtr("visualizerConstellation")
      },
      {
        "key": "radar",
        "name": root.dtr("visualizerRadar")
      }
    ]
    onSelected: key => Settings.data.controlCenter.mediaVisualizerEffect = key
    defaultValue: Settings.getDefaultValue("controlCenter.mediaVisualizerEffect")
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.dtr("settingsAudioSliderEffect")
    description: root.dtr("settingsAudioSliderEffectDesc")
    currentKey: Settings.data.controlCenter.audioSliderEffect
    model: [
      {
        "key": "none",
        "name": root.dtr("sliderEffectNone")
      },
      {
        "key": "wave",
        "name": root.dtr("sliderEffectWave")
      },
      {
        "key": "zigzag",
        "name": root.dtr("sliderEffectZigzag")
      },
      {
        "key": "pulse",
        "name": root.dtr("sliderEffectPulse")
      },
      {
        "key": "bars",
        "name": root.dtr("sliderEffectBars")
      },
      {
        "key": "spectrum",
        "name": root.dtr("sliderEffectSpectrum")
      },
      {
        "key": "filament",
        "name": root.dtr("sliderEffectFilament")
      },
      {
        "key": "ripple",
        "name": root.dtr("sliderEffectRipple")
      },
      {
        "key": "glow",
        "name": root.dtr("sliderEffectGlow")
      },
      {
        "key": "wavy_fill",
        "name": root.dtr("sliderEffectWavyFill")
      },
      {
        "key": "blocks",
        "name": root.dtr("sliderEffectBlocks")
      },
      {
        "key": "dots",
        "name": root.dtr("sliderEffectDots")
      },
      {
        "key": "comet",
        "name": root.dtr("settingsSliderEffectComet")
      },
      {
        "key": "aurora",
        "name": root.dtr("settingsSliderEffectAurora")
      }
    ]
    onSelected: key => Settings.data.controlCenter.audioSliderEffect = key
    defaultValue: Settings.getDefaultValue("controlCenter.audioSliderEffect")
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.dtr("settingsMicSliderEffect")
    description: root.dtr("settingsMicSliderEffectDesc")
    currentKey: Settings.data.controlCenter.microphoneSliderEffect
    model: [
      {
        "key": "none",
        "name": root.dtr("sliderEffectNone")
      },
      {
        "key": "wave",
        "name": root.dtr("sliderEffectWave")
      },
      {
        "key": "zigzag",
        "name": root.dtr("sliderEffectZigzag")
      },
      {
        "key": "pulse",
        "name": root.dtr("sliderEffectPulse")
      },
      {
        "key": "bars",
        "name": root.dtr("sliderEffectBars")
      },
      {
        "key": "glow",
        "name": root.dtr("sliderEffectGlow")
      },
      {
        "key": "wavy_fill",
        "name": root.dtr("sliderEffectWavyFill")
      },
      {
        "key": "blocks",
        "name": root.dtr("sliderEffectBlocks")
      },
      {
        "key": "dots",
        "name": root.dtr("sliderEffectDots")
      },
      {
        "key": "comet",
        "name": root.dtr("settingsSliderEffectComet")
      },
      {
        "key": "aurora",
        "name": root.dtr("settingsSliderEffectAurora")
      }
    ]
    onSelected: key => Settings.data.controlCenter.microphoneSliderEffect = key
    defaultValue: Settings.getDefaultValue("controlCenter.microphoneSliderEffect")
  }

  NHeader {
    label: root.dtr("settingsPerformanceEnergy")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsFollowShellPerf")
    description: root.dtr("settingsFollowShellPerfDesc")
    checked: Settings.data.controlCenter.followHydraPerformanceMode
    onToggled: checked => Settings.data.controlCenter.followHydraPerformanceMode = checked
    defaultValue: Settings.getDefaultValue("controlCenter.followHydraPerformanceMode")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsPowerSaver")
    description: root.dtr("settingsPowerSaverDesc")
    checked: Settings.data.controlCenter.powerSaverPerformanceMode
    onToggled: checked => Settings.data.controlCenter.powerSaverPerformanceMode = checked
    defaultValue: Settings.getDefaultValue("controlCenter.powerSaverPerformanceMode")
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
