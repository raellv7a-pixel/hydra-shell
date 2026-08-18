{
  version ? "dirty",
  m3shapes,
  extraPackages ? [ ],
  runtimeDeps ? [
    brightnessctl
    cliphist
    ddcutil
    wlsunset
    wl-clipboard
    wlr-randr
    imagemagick
    wget
    (python3.withPackages (pp: lib.optional calendarSupport pp.pygobject3))
  ],

  lib,
  stdenv,
  # build
  cmake,
  ninja,
  qt6,
  # runtime deps
  brightnessctl,
  cliphist,
  ddcutil,
  wlsunset,
  wl-clipboard,
  wlr-randr,
  imagemagick,
  wget,
  # GTK3 theme so @define-color overrides from the theming templates actually
  # apply — plain GTK3 apps (no libadwaita) fall back to a non-themeable
  # embedded Adwaita stub without it. Exposed via XDG_DATA_DIRS, not PATH:
  # it ships no binary, only share/themes/adw-gtk3{,-dark}.
  adw-gtk3,
  python3,
  wayland-scanner,
  # calendar support
  calendarSupport ? false,
  evolution-data-server,
  libical,
  glib,
  libsoup_3,
  json-glib,
  gobject-introspection,
}:
let
  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      !(builtins.any (prefix: lib.path.hasPrefix (../. + prefix) (/. + path)) [
        /.github
        /.gitignore
        /Assets/Screenshots
        /Scripts/dev
        /nix
        /LICENSE
        /README.md
        /flake.nix
        /flake.lock
        /shell.nix
        /lefthook.yml
        /CLAUDE.md
        /CREDITS.md
      ]);
  };

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    evolution-data-server
    libical
    glib.out
    libsoup_3
    json-glib
    gobject-introspection
  ];
in
stdenv.mkDerivation {
  pname = "noctalia-shell";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtshadertools
  ];

  buildPhase = ''
    runHook preBuild
    cmake -S plugin -B build/visual-plugin -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DFETCHCONTENT_SOURCE_DIR_M3SHAPES_EXTERNAL=${m3shapes}
    cmake --build build/visual-plugin
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/noctalia-shell $out/bin
    cp -r . $out/share/noctalia-shell
    rm -rf $out/share/noctalia-shell/plugin
    cmake --install build/visual-plugin --prefix "$out"
    ln -s ${quickshell}/bin/qs $out/bin/noctalia-shell
    runHook postInstall
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath (runtimeDeps ++ extraPackages)}
      --prefix XDG_DATA_DIRS : ${wayland-scanner}/share
      --prefix XDG_DATA_DIRS : ${adw-gtk3}/share
      --set-default QS_CONFIG_PATH "$out/share/noctalia-shell"
      --prefix QML_IMPORT_PATH : "$out/lib/qt6/qml"
      ${lib.optionalString calendarSupport "--prefix GI_TYPELIB_PATH : ${giTypelibPath}"}
    )
  '';

  meta = {
    description = "Hydra Shell, a Qt/QML desktop shell for Hyprland";
    homepage = "https://github.com/raellv7a-pixel/hydra-shell";
    license = lib.licenses.gpl3Only;
    mainProgram = "noctalia-shell";
  };
}
