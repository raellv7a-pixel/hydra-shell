{
  description = "Noctalia shell - a Wayland desktop shell built with Quickshell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    noctalia-qs = {
      url = "github:noctalia-dev/noctalia-qs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    m3shapes = {
      url = "github:soramanew/m3shapes/bdc327b29f95394a732baf3c9b19658ba23755b6";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      noctalia-qs,
      m3shapes,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux;
      pkgsFor = eachSystem (
        system:
        nixpkgs.legacyPackages.${system}.appendOverlays [
          self.overlays.default
        ]
      );

      mkDate =
        longDate:
        nixpkgs.lib.concatStringsSep "-" [
          (builtins.substring 0 4 longDate)
          (builtins.substring 4 2 longDate)
          (builtins.substring 6 2 longDate)
        ];

      version = mkDate (self.lastModifiedDate or "19700101") + "_" + (self.shortRev or "dirty");
    in
    {
      formatter = eachSystem (system: pkgsFor.${system}.nixfmt);

      packages = eachSystem (system: {
        default = pkgsFor.${system}.noctalia-shell;
      });

      overlays = {
        default = nixpkgs.lib.composeManyExtensions [
          noctalia-qs.overlays.default
          (final: prev: {
            noctalia-shell = final.callPackage ./nix/package.nix {
              inherit version m3shapes;
            };
          })
        ];
      };

      devShells = eachSystem (system: {
        default = pkgsFor.${system}.callPackage ./nix/shell.nix {
          quickshell = noctalia-qs.packages.${system}.default;
        };
      });

      homeModules.default =
        {
          pkgs,
          lib,
          ...
        }:
        {
          imports = [ ./nix/home-module.nix ];
          programs.noctalia-shell.package =
            lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };

      nixosModules.default =
        {
          pkgs,
          lib,
          ...
        }:
        {
          imports = [ ./nix/nixos-module.nix ];
          services.noctalia-shell.package =
            lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
    };
}
