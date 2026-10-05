import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root
  required property var launcher
  property var folder: null
  property string appId: ""
  property string parentId: ""
  property string chosenIcon: folder ? folder.icon : "folder"
  property bool confirmDelete: false
  color: Qt.alpha(Color.mSurface, 0.92)
  Accessible.role: Accessible.Dialog
  Accessible.name: I18n.tr(folder ? "launcher-home.edit-folder" : (parentId ? "launcher-home.new-subfolder" : "launcher-home.new-folder"))
  MouseArea { anchors.fill: parent }
  NBox {
    anchors.centerIn: parent
    width: Math.min(root.width - Style.margin2XL, 420 * Style.uiScaleRatio)
    height: form.implicitHeight + Style.margin2XL
    color: Color.mSurfaceContainerHigh
    forceOpaque: true
    border.width: 0
    radius: Style.radiusL
    ColumnLayout {
      id: form
      anchors.fill: parent
      anchors.margins: Style.marginXL
      spacing: Style.marginL
      NText { text: root.Accessible.name; pointSize: Style.fontSizeL; font.weight: Style.fontWeightSemiBold }
      NTextInput {
        id: nameInput
        Layout.fillWidth: true
        label: I18n.tr("launcher-home.folder-name")
        text: root.folder ? root.folder.name : ""
        onAccepted: root.save()
        Component.onCompleted: Qt.callLater(() => inputItem.forceActiveFocus())
      }
      Flow {
        visible: !!root.folder
        Layout.fillWidth: true
        spacing: Style.marginS
        Repeater {
          model: ["folder", "briefcase", "code", "palette", "music", "users", "device-gamepad", "star"]
          LauncherHomeButton {
            id: iconChoice
            required property string modelData
            launcher: root.launcher
            text: I18n.tr("launcher-home.icon", { name: modelData })
            width: Math.round(36 * Style.uiScaleRatio)
            height: width
            padding: Style.marginS
            surface: root.chosenIcon === modelData ? Color.mPrimaryContainer : Color.mSurfaceContainerLow
            Accessible.selected: root.chosenIcon === modelData
            contentItem: NIcon { icon: iconChoice.modelData; color: Color.mOnSurface }
            onClicked: root.chosenIcon = modelData
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        LauncherHomeButton {
          launcher: root.launcher
          implicitHeight: Math.round(36 * Style.uiScaleRatio)
          padding: Style.marginS
          visible: !!root.folder
          text: I18n.tr(root.confirmDelete ? "launcher-home.confirm-delete" : "launcher-home.delete-folder")
          foreground: Color.mError
          onClicked: {
            if (!root.confirmDelete) { root.confirmDelete = true; return; }
            root.launcher.browseModel.deleteFolder(root.folder.id, root.parentId);
            root.launcher.closeFolderEditor();
          }
        }
        Item { Layout.fillWidth: true }
        LauncherHomeButton { launcher: root.launcher; text: I18n.tr("common.cancel"); implicitHeight: Math.round(36 * Style.uiScaleRatio); padding: Style.marginS; onClicked: root.launcher.closeFolderEditor() }
        LauncherHomeButton { launcher: root.launcher; text: I18n.tr("common.save"); implicitHeight: Math.round(36 * Style.uiScaleRatio); padding: Style.marginS; surface: Color.mPrimaryContainer; foreground: Color.mOnPrimaryContainer; enabled: nameInput.text.trim() !== ""; onClicked: root.save() }
      }
    }
  }
  function save() {
    if (launcher.browseModel.saveFolder(folder?.id || "", nameInput.text, chosenIcon, appId, parentId)) {
      launcher.closeFolderEditor();
      launcher.refreshAppPanelActions();
      launcher.updateResults();
    }
  }
  Keys.onEscapePressed: launcher.closeFolderEditor()
}
