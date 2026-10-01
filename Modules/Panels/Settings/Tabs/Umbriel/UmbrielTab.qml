import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "Chords.js" as Chords
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  implicitHeight: content.implicitHeight
  width: parent ? parent.width : 800

  property string query: ""
  property string category: "Todas"
  property string recordTarget: ""
  property string forming: ""
  property string advancedId: ""
  readonly property bool recording: recordTarget !== ""
  readonly property var store: UmbrielKeybindStore
  readonly property var categories: ["Todas"].concat([...new Set(store.catalog.map(row => row.category)), "Personalizados"])
  readonly property var visibleRows: store.rows.filter(row => {
                                                         if (category !== "Todas" && row.category !== category)
                                                         return false;
                                                         const text = (row.label + " " + row.chord + " " + row.action + " " + row.category).toLowerCase();
                                                         return text.indexOf(query.toLowerCase()) !== -1;
                                                       })
  readonly property bool invalidRows: store.rows.some(row => !Chords.normalize(row.chord) || !row.action || !row.label)

  Component.onCompleted: store.init()
  Component.onDestruction: {
    PanelService.isKeybindRecording = false;
  }

  function startRecord(id) {
    if (recording)
      return;
    recordTarget = id;
    forming = "Aguardando inibição da Umbriel…";
    PanelService.isKeybindRecording = true;
    captureTimeout.restart();
  }

  function stopRecord(value) {
    captureTimeout.stop();
    const id = recordTarget;
    recordTarget = "";
    forming = "";
    PanelService.isKeybindRecording = false;
    if (!value)
      return;
    if (id.startsWith("custom."))
      store.editCustom(Number(id.slice(7)), "chord", value);
    else
      store.rebind(id, value);
  }

  ShortcutInhibitor {
    id: inhibitor
    window: root.QsWindow ? root.QsWindow.window : null
    enabled: root.recording
    onActiveChanged: {
      if (active && root.recording)
        capture.forceActiveFocus();
    }
    onCancelled: root.stopRecord("")
  }

  Timer {
    id: captureTimeout
    interval: 15000
    onTriggered: {
      root.stopRecord("");
      root.store.error = "Tempo de gravação esgotado. Nenhum atalho foi alterado.";
    }
  }

  ColumnLayout {
    id: content
    width: root.width
    spacing: Style.marginL

    NSettingsSection {
      icon: "keyboard"
      title: "Umbriel · Atalhos"
      description: "Catálogo Hydra. As ações do compositor são nativas; as superfícies usam o IPC da Hydra. Edite e salve para aplicar."

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        NTextInput {
          id: searchInput
          Layout.fillWidth: true
          placeholderText: "Pesquisar descrição, ação ou combinação"
          onTextChanged: root.query = text
        }
        NComboBox {
          Layout.preferredWidth: 210
          model: root.categories.map(value => ({
                                                 key: value,
                                                 name: value
                                               }))
          currentKey: root.category
          onSelected: key => root.category = key
        }
      }

      NText {
        visible: !root.store.loaded
        text: root.store.busy ? "Carregando atalhos…" : "Não foi possível carregar o catálogo."
        color: Color.mOnSurfaceVariant
      }
      NText {
        visible: root.store.error !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.store.error
        color: Color.mError
      }
      NText {
        visible: root.store.hasConflicts
        text: "Resolva os conflitos antes de salvar."
        color: Color.mError
      }

      NButton {
        text: "Adicionar atalho personalizado"
        icon: "add"
        onClicked: {
          root.store.addCustom();
          root.category = "Personalizados";
          searchInput.text = "";
          root.advancedId = "custom." + (root.store.draft.custom.length - 1);
        }
      }

      RowLayout {
        Layout.fillWidth: true
        NText {
          Layout.fillWidth: true
          text: root.store.dirty ? "Alterações não salvas" : "Configuração atual"
          color: Color.mOnSurfaceVariant
        }
        NButton {
          text: "Restaurar padrões"
          outlined: true
          enabled: root.store.loaded && !root.store.busy
          onClicked: root.store.restoreDefaults()
        }
        NButton {
          text: "Reverter"
          outlined: true
          enabled: root.store.dirty && !root.store.busy
          onClicked: root.store.revert()
        }
        NButton {
          text: root.store.busy ? "Validando…" : "Salvar"
          enabled: root.store.loaded && root.store.dirty && !root.store.busy && !root.store.hasConflicts && !root.invalidRows
          onClicked: root.store.save()
        }
      }
      Repeater {
        model: root.visibleRows
        delegate: ColumnLayout {
          id: rowItem
          required property var modelData
          Layout.fillWidth: true
          spacing: Style.marginS
          readonly property bool isCustom: modelData.category === "Personalizados"
          readonly property int customIndex: isCustom ? Number(modelData.id.slice(7)) : -1
          readonly property string conflict: root.store.conflicts[modelData.id] || ""

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM
            ColumnLayout {
              Layout.fillWidth: true
              NText {
                text: rowItem.modelData.label
                font.weight: Font.DemiBold
                color: Color.mOnSurface
              }
              NText {
                text: rowItem.modelData.category + " · " + rowItem.modelData.type + " · " + rowItem.modelData.action
                color: Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeS
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              NText {
                visible: !rowItem.isCustom
                text: "Padrão: " + (root.store.catalog.find(e => e.id === rowItem.modelData.id)?.chord || "")
                color: Color.mOnSurfaceVariant
              }
              NText {
                visible: rowItem.conflict !== "" || !Chords.normalize(rowItem.modelData.chord)
                text: rowItem.conflict ? "Conflito com: " + rowItem.conflict : "Combinação inválida"
                color: Color.mError
              }
            }
            NButton {
              text: rowItem.modelData.chord || "Gravar"
              outlined: true
              onClicked: root.startRecord(rowItem.modelData.id)
            }
            NIconButton {
              icon: rowItem.isCustom ? "trash" : "restore"
              tooltipText: rowItem.isCustom ? "Remover atalho" : "Restaurar combinação padrão"
              onClicked: {
                if (rowItem.isCustom)
                  root.store.removeCustom(rowItem.customIndex);
                else
                  root.store.rebind(rowItem.modelData.id, root.store.catalog.find(e => e.id === rowItem.modelData.id).chord);
              }
            }
            NIconButton {
              visible: rowItem.isCustom
              icon: "settings"
              tooltipText: "Editar ação e opções"
              onClicked: root.advancedId = root.advancedId === rowItem.modelData.id ? "" : rowItem.modelData.id
            }
          }

          ColumnLayout {
            visible: rowItem.isCustom && root.advancedId === rowItem.modelData.id
            Layout.fillWidth: true
            spacing: Style.marginS
            NTextInput {
              Layout.fillWidth: true
              label: "Descrição"
              text: rowItem.modelData.label || ""
              onEditingFinished: root.store.editCustom(rowItem.customIndex, "label", text.trim())
            }
            NTextInput {
              Layout.fillWidth: true
              label: "Combinação (ou grave com o botão acima)"
              text: rowItem.modelData.chord || ""
              onEditingFinished: root.store.editCustom(rowItem.customIndex, "chord", Chords.normalize(text) || text.trim())
            }
            NComboBox {
              Layout.fillWidth: true
              label: "Tipo"
              model: [
                {
                  key: "umbriel",
                  name: "Ação nativa Umbriel"
                },
                {
                  key: "hydra",
                  name: "IPC Hydra"
                },
                {
                  key: "command",
                  name: "Executar comando"
                }
              ]
              currentKey: rowItem.modelData.type
              onSelected: key => {
                            root.store.editCustom(rowItem.customIndex, "type", key);
                            root.store.editCustom(rowItem.customIndex, "action", "");
                          }
            }
            NComboBox {
              visible: rowItem.modelData.type === "hydra"
              Layout.fillWidth: true
              label: "Função Hydra"
              model: Object.keys(root.store.ipc).reduce((all, target) => all.concat(root.store.ipc[target].map(fn => ({
                                                                                                                        key: target + " " + fn,
                                                                                                                        name: target + " · " + fn
                                                                                                                      }))), [])
              currentKey: rowItem.modelData.action
              onSelected: key => root.store.editCustom(rowItem.customIndex, "action", key)
            }
            NTextInput {
              visible: rowItem.modelData.type !== "hydra"
              Layout.fillWidth: true
              label: rowItem.modelData.type === "umbriel" ? "Ação nativa (ex.: overview-toggle)" : "Comando"
              text: rowItem.modelData.action || ""
              onEditingFinished: root.store.editCustom(rowItem.customIndex, "action", text.trim())
            }
            RowLayout {
              Layout.fillWidth: true
              NCheckbox {
                Layout.fillWidth: true
                label: "Repetir"
                checked: rowItem.modelData.repeat || false
                onToggled: checked => root.store.editCustom(rowItem.customIndex, "repeat", checked)
              }
              NCheckbox {
                Layout.fillWidth: true
                label: "Durante bloqueio"
                checked: rowItem.modelData.allow_when_locked || false
                onToggled: checked => root.store.editCustom(rowItem.customIndex, "allow_when_locked", checked)
              }
              NCheckbox {
                Layout.fillWidth: true
                label: "Com inibição"
                checked: rowItem.modelData.allow_when_inhibited || false
                onToggled: checked => root.store.editCustom(rowItem.customIndex, "allow_when_inhibited", checked)
              }
            }
            NTextInput {
              Layout.preferredWidth: 220
              label: "Cooldown (ms)"
              text: String(rowItem.modelData.cooldown_ms || 0)
              onEditingFinished: root.store.editCustom(rowItem.customIndex, "cooldown_ms", Number(text))
            }
          }
          NDivider {
            Layout.fillWidth: true
          }
        }
      }
    }
  }

  Popup {
    id: recorderPopup
    anchors.centerIn: Overlay.overlay
    width: Math.min(500, Overlay.overlay.width - Style.marginXL * 2)
    height: 250
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose
    visible: root.recording
    onOpened: capture.forceActiveFocus()
    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mPrimary
    }
    Item {
      id: capture
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
                        event.accepted = true;
                        if (event.key === Qt.Key_Escape) {
                          root.stopRecord("");
                          return;
                        }
                        if (!inhibitor.active)
                        return;
                        const chord = Chords.fromEvent(event);
                        if (chord)
                        root.stopRecord(chord);
                        else
                        root.forming = "Mod / Ctrl / Alt / Shift + tecla…";
                      }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.marginL
        NText {
          text: inhibitor.active ? "Grave a combinação" : "Aguardando proteção de atalhos…"
          font.pointSize: Style.fontSizeXL
        }
        NText {
          text: root.forming
          color: Color.mOnSurfaceVariant
        }
        NText {
          text: "Escape cancela · timeout: 15 s"
          color: Color.mOnSurfaceVariant
        }
        NButton {
          text: "Cancelar"
          outlined: true
          onClicked: root.stopRecord("")
        }
      }
    }
  }
}
