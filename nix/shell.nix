{
  quickshell,
  nixfmt,
  statix,
  deadnix,
  shfmt,
  shellcheck,
  jsonfmt,
  lefthook,
  kdePackages,
  mkShellNoCC,
  python3,
}:
mkShellNoCC {
  #it's faster than mkDerivation / mkShell
  packages = [
    quickshell
    (python3.withPackages (pp: [ (pp.callPackage ./materialyoucolor.nix { }) ]))

    # nix
    nixfmt # formatter
    statix # linter
    deadnix # linter

    # shell
    shfmt # formatter
    shellcheck # linter

    # json
    jsonfmt # formatter

    # CoC
    lefthook # githooks
    kdePackages.qtdeclarative # qmlfmt, qmllint, qmlls and etc; Qt6
  ];
}
