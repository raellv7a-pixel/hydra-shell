var applicationIcons = {
  all: "grid-dots",
  AudioVideo: "folder-multimedia",
  Chat: "users",
  Development: "folder-development",
  Education: "folder-education",
  Game: "folder-games",
  Graphics: "folder-creativity",
  Network: "settings-network",
  Office: "folder-productivity",
  System: "folder-system",
  Misc: "folder-utilities",
  WebBrowser: "folder-internet"
};

var smartFolderIcons = {
  tools: "folder-tools",
  productivity: "folder-productivity",
  creativity: "folder-creativity",
  social: "users",
  games: "folder-games",
  media: "folder-multimedia"
};

var manualFolderIcons = {
  briefcase: "folder-productivity",
  code: "folder-development",
  palette: "folder-creativity",
  "device-gamepad": "folder-games"
};

function categoryIcon(category, provider, defaultProvider) {
  if (provider === defaultProvider && applicationIcons[category])
    return applicationIcons[category];
  return provider?.categoryIcons?.[category] || "grid-dots";
}

function folderIcon(folder) {
  if (folder.mode === "smart")
    return smartFolderIcons[folder.id] || folder.icon || "folder";
  return manualFolderIcons[folder.icon] || folder.icon || "folder";
}
