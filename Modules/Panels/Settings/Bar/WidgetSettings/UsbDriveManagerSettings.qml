import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  property bool valueHideWhenEmpty: widgetData.hideWhenEmpty !== undefined ? widgetData.hideWhenEmpty : widgetMetadata.hideWhenEmpty
  property bool valueShowBadge: widgetData.showBadge !== undefined ? widgetData.showBadge : widgetMetadata.showBadge
  property string valueIconColor: widgetData.iconColor !== undefined ? widgetData.iconColor : widgetMetadata.iconColor

  function saveWidgetSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.hideWhenEmpty = valueHideWhenEmpty;
    settings.showBadge = valueShowBadge;
    settings.iconColor = valueIconColor;
    settingsChanged(settings);
  }

  NText {
    text: I18n.tr("usb-drive-manager.settings.widget-section")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.hide-when-empty")
    description: I18n.tr("usb-drive-manager.settings.hide-when-empty-description")
    checked: root.valueHideWhenEmpty
    defaultValue: widgetMetadata.hideWhenEmpty
    onToggled: checked => {
      root.valueHideWhenEmpty = checked;
      root.saveWidgetSettings();
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.show-badge")
    description: I18n.tr("usb-drive-manager.settings.show-badge-description")
    checked: root.valueShowBadge
    defaultValue: widgetMetadata.showBadge
    onToggled: checked => {
      root.valueShowBadge = checked;
      root.saveWidgetSettings();
    }
  }

  NColorChoice {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.icon-color")
    description: I18n.tr("usb-drive-manager.settings.icon-color-description")
    currentKey: root.valueIconColor
    defaultValue: widgetMetadata.iconColor
    onSelected: key => {
      root.valueIconColor = key;
      root.saveWidgetSettings();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: I18n.tr("usb-drive-manager.settings.behavior-section")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.auto-mount")
    description: I18n.tr("usb-drive-manager.settings.auto-mount-description")
    checked: Settings.data.usbDriveManager.autoMount
    defaultValue: false
    onToggled: checked => Settings.data.usbDriveManager.autoMount = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.notifications")
    description: I18n.tr("usb-drive-manager.settings.notifications-description")
    checked: Settings.data.usbDriveManager.showNotifications
    defaultValue: true
    onToggled: checked => Settings.data.usbDriveManager.showNotifications = checked
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.file-browser")
    description: I18n.tr("usb-drive-manager.settings.file-browser-description")
    model: [
      { "key": "xdg-open", "name": "xdg-open" },
      { "key": "dolphin", "name": "Dolphin" },
      { "key": "thunar", "name": "Thunar" },
      { "key": "nautilus", "name": "Nautilus" },
      { "key": "yazi", "name": "Yazi" },
      { "key": "ranger", "name": "Ranger" },
      { "key": "lf", "name": "lf" },
      { "key": "nnn", "name": "nnn" }
    ]
    currentKey: Settings.data.usbDriveManager.fileBrowser
    defaultValue: "xdg-open"
    onSelected: key => Settings.data.usbDriveManager.fileBrowser = key
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("usb-drive-manager.settings.terminal")
    description: I18n.tr("usb-drive-manager.settings.terminal-description")
    model: [
      { "key": "kitty", "name": "Kitty" },
      { "key": "foot", "name": "foot" },
      { "key": "alacritty", "name": "Alacritty" },
      { "key": "wezterm", "name": "WezTerm" },
      { "key": "ghostty", "name": "Ghostty" },
      { "key": "ptyxis", "name": "Ptyxis" },
      { "key": "gnome-terminal", "name": "GNOME Terminal" }
    ]
    currentKey: Settings.data.usbDriveManager.terminal
    defaultValue: "kitty"
    onSelected: key => Settings.data.usbDriveManager.terminal = key
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: !UsbDriveService.dependenciesChecked
          ? I18n.tr("usb-drive-manager.settings.checking-dependencies")
          : UsbDriveService.missingDependencies.length === 0
            ? I18n.tr("usb-drive-manager.settings.dependencies-ready")
            : I18n.tr("usb-drive-manager.settings.dependencies-missing", { "programs": UsbDriveService.missingDependencies.join(", ") })
    pointSize: Style.fontSizeXS
    color: UsbDriveService.dependenciesChecked && UsbDriveService.missingDependencies.length > 0 ? Color.mError : Color.mOnSurfaceVariant
    wrapMode: Text.Wrap
  }
}