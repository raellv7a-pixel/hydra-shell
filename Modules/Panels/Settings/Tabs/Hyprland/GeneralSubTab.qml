import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Appearance (general/decoration) + tiling layout picker. Every control
// reads/writes HyprlandDraftStore.val()/edit() — appearance is one of the
// two previewable roots (see HyprlandDraftStore._previewableRoots), so
// dragging a slider here applies live via `hyprctl eval`, no Save needed to
// see the change; Save is only needed to persist it.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NSettingsSection {
    icon: "layout-grid"
    title: "Layout de janelas"
    description: "Como novas janelas se organizam na tela"

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      Repeater {
        model: [
          {
            "key": "dwindle",
            "label": "Dwindle"
          },
          {
            "key": "master",
            "label": "Master"
          },
          {
            "key": "scrolling",
            "label": "Scrolling"
          }
        ]
        delegate: NButton {
          required property var modelData
          text: modelData.label
          outlined: HyprlandDraftStore.val("appearance.layout") !== modelData.key
          onClicked: HyprlandDraftStore.edit("appearance.layout", modelData.key)
        }
      }
    }
  }

  NSettingsSection {
    icon: "spacing"
    title: "Espaçamento e borda"

    NValueSlider {
      Layout.fillWidth: true
      label: "Espaçamento interno"
      description: "Entre janelas lado a lado, em pixels"
      from: 0
      to: 40
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.gapsIn")
      onMoved: v => HyprlandDraftStore.edit("appearance.gapsIn", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.gapsIn")) + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Espaçamento externo"
      description: "Entre janelas e a borda da tela, em pixels"
      from: 0
      to: 60
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.gapsOut")
      onMoved: v => HyprlandDraftStore.edit("appearance.gapsOut", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.gapsOut")) + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Espessura da borda"
      from: 0
      to: 8
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.borderSize")
      onMoved: v => HyprlandDraftStore.edit("appearance.borderSize", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.borderSize")) + "px"
    }

    NToggle {
      Layout.fillWidth: true
      label: "Redimensionar pela borda"
      description: "Arrastar a borda ou o espaçamento de uma janela para redimensionar"
      checked: HyprlandDraftStore.val("appearance.resizeOnBorder")
      onToggled: checked => HyprlandDraftStore.edit("appearance.resizeOnBorder", checked)
    }

    NToggle {
      Layout.fillWidth: true
      label: "Permitir tearing"
      description: "Reduz latência em jogos com allow_tearing, à custa de possíveis artefatos visuais"
      checked: HyprlandDraftStore.val("appearance.allowTearing")
      onToggled: checked => HyprlandDraftStore.edit("appearance.allowTearing", checked)
    }
  }

  NSettingsSection {
    icon: "border-corners"
    title: "Cantos e opacidade"

    NValueSlider {
      Layout.fillWidth: true
      label: "Raio dos cantos"
      from: 0
      to: 30
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.rounding")
      onMoved: v => HyprlandDraftStore.edit("appearance.rounding", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.rounding")) + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Opacidade — janela ativa"
      from: 0.3
      to: 1.0
      stepSize: 0.01
      value: HyprlandDraftStore.val("appearance.activeOpacity")
      onMoved: v => HyprlandDraftStore.edit("appearance.activeOpacity", v)
      text: Math.round(HyprlandDraftStore.val("appearance.activeOpacity") * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Opacidade — janelas inativas"
      from: 0.3
      to: 1.0
      stepSize: 0.01
      value: HyprlandDraftStore.val("appearance.inactiveOpacity")
      onMoved: v => HyprlandDraftStore.edit("appearance.inactiveOpacity", v)
      text: Math.round(HyprlandDraftStore.val("appearance.inactiveOpacity") * 100) + "%"
    }
  }

  NSettingsSection {
    icon: "shadow"
    title: "Sombra"

    NToggle {
      Layout.fillWidth: true
      label: "Ativar sombra"
      checked: HyprlandDraftStore.val("appearance.shadowEnabled")
      onToggled: checked => HyprlandDraftStore.edit("appearance.shadowEnabled", checked)
    }

    NValueSlider {
      Layout.fillWidth: true
      enabled: HyprlandDraftStore.val("appearance.shadowEnabled")
      label: "Alcance da sombra"
      from: 0
      to: 30
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.shadowRange")
      onMoved: v => HyprlandDraftStore.edit("appearance.shadowRange", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.shadowRange")) + "px"
    }
  }

  NSettingsSection {
    icon: "blur"
    title: "Desfoque (blur)"

    NToggle {
      Layout.fillWidth: true
      label: "Ativar desfoque"
      checked: HyprlandDraftStore.val("appearance.blurEnabled")
      onToggled: checked => HyprlandDraftStore.edit("appearance.blurEnabled", checked)
    }

    NValueSlider {
      Layout.fillWidth: true
      enabled: HyprlandDraftStore.val("appearance.blurEnabled")
      label: "Tamanho do desfoque"
      from: 1
      to: 20
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.blurSize")
      onMoved: v => HyprlandDraftStore.edit("appearance.blurSize", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.blurSize")) + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      enabled: HyprlandDraftStore.val("appearance.blurEnabled")
      label: "Passadas de desfoque"
      description: "Mais passadas = desfoque mais amplo, maior custo de GPU"
      from: 1
      to: 6
      stepSize: 1
      value: HyprlandDraftStore.val("appearance.blurPasses")
      onMoved: v => HyprlandDraftStore.edit("appearance.blurPasses", Math.round(v))
      text: Math.round(HyprlandDraftStore.val("appearance.blurPasses"))
    }

    NToggle {
      Layout.fillWidth: true
      enabled: HyprlandDraftStore.val("appearance.blurEnabled")
      label: "Desfoque X-ray"
      description: "Desfoca só o wallpaper, ignorando janelas por trás"
      checked: HyprlandDraftStore.val("appearance.blurXray")
      onToggled: checked => HyprlandDraftStore.edit("appearance.blurXray", checked)
    }
  }

  NSettingsSection {
    icon: "sparkles"
    title: "Animações"

    NToggle {
      Layout.fillWidth: true
      label: "Ativar animações"
      description: "Interruptor mestre — as curvas e velocidades individuais ficam na aba Animações"
      checked: HyprlandDraftStore.val("appearance.animationsEnabled")
      onToggled: checked => HyprlandDraftStore.edit("appearance.animationsEnabled", checked)
    }
  }
}
