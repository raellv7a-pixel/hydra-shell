pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root
  property string label: I18n.tr("panels.umbriel.picker-label")
  property string action: ""
  property string query: ""
  readonly property var catalog: UmbrielActionStore.catalog
  property string pendingAction: ""
  property bool pendingRequired: false
  property string pendingHint: ""
  signal selected(string action)
  property bool pickerOpen: false
  property bool advancedOpen: false
  readonly property string displayAction: {
    if (!action) return I18n.tr("panels.umbriel.picker-none");
    const key = action.split(":")[0];
    const item = catalog.find(entry => entry.key === key);
    return item ? descriptionFor(item) + (action.length > key.length ? " · " + action.slice(key.length + 1) : "") : action;
  }
  onSelected: {
    pickerOpen = false;
    advancedOpen = false;
    pendingAction = "";
    pendingRequired = false;
    pendingHint = "";
    query = "";
    actionSearch.text = "";
  }
  Layout.fillWidth: true
  spacing: Style.marginS

  readonly property var matches: {
    const q = query.toLowerCase().trim();
    return q ? catalog.filter(item => (item.key + " " + item.name + " " + item.category + " " + root.descriptionFor(item)).toLowerCase().includes(q)).slice(0, 8) : [];
  }
  function togglePicker() {
    pickerOpen = !pickerOpen;
    if (!pickerOpen) {
      advancedOpen = false;
      pendingAction = "";
      pendingRequired = false;
      pendingHint = "";
      query = "";
      actionSearch.text = "";
    }
  }
  function descriptionFor(item) {
    const pt = {
      "overview-toggle": "Alternar Visão Geral",
      "overview-open": "Abrir Visão Geral",
      "overview-close": "Fechar Visão Geral",
      "workspace-next": "Próximo workspace",
      "workspace-previous": "Workspace anterior",
      "workspace-switch": "Ir para workspace",
      "scratchpad-toggle": "Mostrar ou ocultar scratchpad",
      "window-close": "Fechar janela",
      "window-toggle-floating": "Alternar janela flutuante",
      "window-toggle-fullscreen": "Alternar tela cheia",
      "cheatsheet-toggle": "Mostrar ou ocultar atalhos"
    };
    return I18n.langCode.startsWith("pt") && pt[item.key] ? pt[item.key] : item.name;
  }

  Component.onCompleted: UmbrielActionStore.ensureLoaded()
  NText { visible: UmbrielActionStore.error !== ""; text: UmbrielActionStore.error; color: Color.mError; Layout.fillWidth: true; wrapMode: Text.Wrap }
  NText {
    text: root.label
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeM
  }
  Rectangle {
    id: selector
    Layout.fillWidth: true
    implicitHeight: Style.baseWidgetSize * 1.25 * Style.uiScaleRatio
    radius: Style.iRadiusL
    color: root.pickerOpen || selectorHover.containsMouse ? Color.mSecondaryContainer : Color.mSurfaceContainerHighest
    border.color: activeFocus ? Color.mPrimary : "transparent"
    border.width: activeFocus ? Style.borderM : 0
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.label + ": " + root.displayAction
    Keys.onReturnPressed: root.togglePicker()
    Keys.onSpacePressed: root.togglePicker()
    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation { duration: selectorHover.containsMouse ? Style.hoverEnterDuration : Style.hoverLeaveDuration }
    }
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.marginL
      anchors.rightMargin: Style.marginL
      spacing: Style.marginM
      NIcon { icon: "bolt"; color: root.pickerOpen || selectorHover.containsMouse ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant; pointSize: Style.fontSizeM }
      NText {
        Layout.fillWidth: true
        text: root.displayAction
        color: root.pickerOpen || selectorHover.containsMouse ? Color.mOnSecondaryContainer : Color.mOnSurface
        elide: Text.ElideRight
      }
      NIcon {
        icon: "chevron-down"
        color: root.pickerOpen || selectorHover.containsMouse ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
        rotation: root.pickerOpen ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Style.animationFast } }
      }
    }
    MouseArea {
      id: selectorHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.togglePicker()
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.pickerOpen
    spacing: Style.marginM
    UmbrielSearchField {
      id: actionSearch
      label: I18n.tr("panels.umbriel.picker-search")
      placeholderText: I18n.tr("panels.umbriel.picker-search-placeholder")
      text: root.query
      onTextChanged: root.query = text
    }
    Repeater {
      model: root.matches
      delegate: NButton {
        required property var modelData
        Layout.fillWidth: true
        backgroundColor: Color.mSurfaceContainerHigh
        textColor: Color.mOnSurface
        hoverColor: Color.mSurfaceContainerHighest
        textHoverColor: Color.mOnSurface
        text: modelData.category + " · " + root.descriptionFor(modelData)
        tooltipText: modelData.name + " (" + modelData.signature + ")"
        onClicked: {
          root.pendingAction = modelData.key;
          root.pendingRequired = modelData.required;
          root.pendingHint = modelData.argument;
          if (!modelData.required)
            root.selected(modelData.key);
        }
      }
    }
    NTextInput {
      id: argumentInput
      Layout.fillWidth: true
      visible: root.pendingRequired || root.pendingHint !== ""
      label: "Argumento " + root.pendingHint
      placeholderText: "Digite o valor do argumento"
    }
    NButton {
      visible: root.pendingRequired || (root.pendingHint !== "" && argumentInput.text.trim() !== "")
      text: "Usar ação com argumento"
      enabled: argumentInput.text.trim() !== ""
      onClicked: root.selected(root.pendingAction + ":" + argumentInput.text.trim())
    }
    NButton {
      text: root.advancedOpen ? I18n.tr("panels.umbriel.picker-custom-hide") : I18n.tr("panels.umbriel.picker-custom-show")
      icon: "code"
      backgroundColor: Color.mSurfaceContainerHigh
      textColor: Color.mOnSurfaceVariant
      hoverColor: Color.mSurfaceContainerHighest
      textHoverColor: Color.mOnSurface
      onClicked: root.advancedOpen = !root.advancedOpen
    }
    NTextInput {
      visible: root.advancedOpen
      Layout.fillWidth: true
      label: I18n.tr("panels.umbriel.picker-advanced")
      description: I18n.tr("panels.umbriel.picker-advanced-description")
      text: root.action
      onEditingFinished: {
        const value = text.trim();
        if (value)
          root.selected(value);
      }
    }
  }
}
