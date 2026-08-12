{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.noctalia-shell;
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };

  generateJson =
    name: value:
    if lib.isString value then
      pkgs.writeText "noctalia-${name}.json" value
    else if builtins.isPath value || lib.isStorePath value then
      value
    else
      jsonFormat.generate "noctalia-${name}.json" value;
in
{
  options.programs.noctalia-shell = {
    enable = lib.mkEnableOption "Noctalia shell configuration";

    systemd.enable = lib.mkEnableOption "Noctalia shell systemd integration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The noctalia-shell package to use";
    };

    settings = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          bar = {
            position = "bottom";
            floating = true;
            backgroundOpacity = 0.95;
          };
          general = {
            animationSpeed = 1.5;
            radiusRatio = 1.2;
          };
          colorSchemes = {
            darkMode = true;
            useWallpaperColors = true;
          };
        }
      '';
      description = ''
        Noctalia shell configuration settings as an attribute set, string
        or filepath, to be written to ~/.config/noctalia/settings.json.
      '';
    };

    colors = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
         {
           mError = "#dddddd";
           mOnError = "#111111";
           mOnPrimary = "#111111";
           mOnSecondary = "#111111";
           mOnSurface = "#828282";
           mOnSurfaceVariant = "#5d5d5d";
           mOnTertiary = "#111111";
           mOutline = "#3c3c3c";
           mPrimary = "#aaaaaa";
           mSecondary = "#a7a7a7";
           mShadow = "#000000";
           mSurface = "#111111";
           mSurfaceVariant = "#191919";
           mTertiary = "#cccccc";
        }
      '';
      description = ''
        Noctalia shell color configuration as an attribute set, string
        or filepath, to be written to ~/.config/noctalia/colors.json.
      '';
    };

    user-templates = lib.mkOption {
      default = { };
      type =
        with lib.types;
        oneOf [
          tomlFormat.type
          str
          path
        ];
      example = lib.literalExpression ''
        {
          templates = {
            neovim = {
              input_path = "~/.config/noctalia/templates/template.lua";
              output_path = "~/.config/nvim/generated.lua";
              post_hook = "pkill -SIGUSR1 nvim";
            };
          };
        }
      '';
      description = ''
        Template definitions for Noctalia, to be written to ~/.config/noctalia/user-templates.toml.

        This option accepts:
        - a Nix attrset (converted to TOML automatically)
        - a string containing raw TOML
        - a path to an existing TOML file
      '';
    };

    plugins = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          sources = [
            {
              enabled = true;
              name = "Noctalia Plugins";
              url = "https://github.com/noctalia-dev/noctalia-plugins";
            }
          ];
          states = {
            catwalk = {
              enabled = true;
              sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
            };
          };
          version = 2;
        }
      '';
      description = ''
        Noctalia shell plugin configuration as an attribute set, string
        or filepath, to be written to ~/.config/noctalia/plugins.json.
      '';
    };

    pluginSettings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          jsonFormat.type
          str
          path
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          catwalk = {
            minimumThreshold = 25;
            hideBackground = true;
          };
        }
      '';
      description = ''
        Each plugin’s settings as an attribute set, string
        or filepath, to be written to ~/.config/noctalia/plugins/plugin-name/settings.json.
      '';
    };

    hyprland = {
      enable = lib.mkEnableOption ''
        letting noctalia-shell manage ~/.config/hypr/hyprland.lua and
        ~/.config/hypr/modules, symlinked from the package's own
        Assets/Hyprland (see PLANO_INTEGRACAO_HYPRMOD.md §4.3). This is the
        declarative equivalent of accepting the adoption offer in the Setup
        Wizard's Hyprland step — use one or the other, not both, on the same
        machine.

        NOT managed by this option, by design: ~/.config/hypr/user.lua
        (hand-edited, must stay mutable — put personal Hyprland overrides in
        your home-manager config and materialize them as a separate
        xdg.configFile entry instead) and
        ~/.config/hypr/hydra-shell/{settings,rebinds}.lua (written at runtime
        by the Settings panel, also must stay mutable)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.mkIf cfg.systemd.enable [
      ''
        Running noctalia-shell as a systemd service has been deprecated!
        See https://docs.noctalia.dev/getting-started/nixos/#running-the-shell for details.
      ''
    ];

    systemd.user.services.noctalia-shell = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Noctalia Shell - Wayland desktop shell";
        Documentation = "https://docs.noctalia.dev";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers =
          lib.optional (cfg.settings != { }) "${config.xdg.configFile."noctalia/settings.json".source}"
          ++ lib.optional (cfg.colors != { }) "${config.xdg.configFile."noctalia/colors.json".source}"
          ++ lib.optional (cfg.plugins != { }) "${config.xdg.configFile."noctalia/plugins.json".source}"
          ++ lib.optional (
            cfg.user-templates != { }
          ) "${config.xdg.configFile."noctalia/user-templates.toml".source}"
          ++ lib.mapAttrsToList (
            name: _: "${config.xdg.configFile."noctalia/plugins/${name}/settings.json".source}"
          ) cfg.pluginSettings;
      };

      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    home.packages = lib.optional (cfg.package != null) cfg.package;

    xdg.configFile = {
      "noctalia/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = generateJson "settings" cfg.settings;
      };
      "noctalia/colors.json" = lib.mkIf (cfg.colors != { }) {
        source = generateJson "colors" cfg.colors;
      };
      "noctalia/plugins.json" = lib.mkIf (cfg.plugins != { }) {
        source = generateJson "plugins" cfg.plugins;
      };
      "noctalia/user-templates.toml" = lib.mkIf (cfg.user-templates != { }) {
        source =
          if lib.isString cfg.user-templates then
            pkgs.writeText "noctalia-user-templates.toml" cfg.user-templates
          else if builtins.isPath cfg.user-templates || lib.isStorePath cfg.user-templates then
            cfg.user-templates
          else
            tomlFormat.generate "noctalia-user-templates.toml" cfg.user-templates;
      };
      "hypr/hyprland.lua" = lib.mkIf cfg.hyprland.enable {
        source = "${cfg.package}/share/noctalia-shell/Assets/Hyprland/hyprland.lua";
      };
      "hypr/modules" = lib.mkIf cfg.hyprland.enable {
        source = "${cfg.package}/share/noctalia-shell/Assets/Hyprland/modules";
      };
    }
    // lib.mapAttrs' (
      name: value:
      lib.nameValuePair "noctalia/plugins/${name}/settings.json" {
        source = generateJson "${name}-settings" value;
      }
    ) cfg.pluginSettings;

    assertions = [
      {
        assertion = !cfg.systemd.enable || cfg.package != null;
        message = "noctalia-shell: The package option must not be null when systemd service is enabled.";
      }
      {
        assertion = !cfg.hyprland.enable || cfg.package != null;
        message = "noctalia-shell: The package option must not be null when programs.noctalia-shell.hyprland.enable is set.";
      }
    ];
  };
}
