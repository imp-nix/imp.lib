/*
  Flake-parts module for imp.

  Automatically loads flake outputs from a directory structure:

    outputs/
      perSystem/
        packages.nix     -> perSystem.packages
        devShells.nix    -> perSystem.devShells
      nixosConfigurations/
        server.nix       -> flake.nixosConfigurations.server
      overlays.nix       -> flake.overlays

  Usage:

    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.imp.flakeModules.default ];

      imp = {
        src = ./outputs;
        args = { inherit inputs; };
      };

      systems = [ "x86_64-linux" "aarch64-linux" ];
    };

  The module passes these arguments to each file:
    - perSystem files: { pkgs, lib, system, self, self', inputs, inputs', ... } // args
    - flake files: { lib, self, inputs, ... } // args

  User-provided args take precedence over module defaults, allowing you to
  override lib with a custom extended version (e.g., nixpkgs.lib).

  Files can be:
    - Functions: called with args, result used as output
    - Attrsets: used directly as output
*/
{
  lib,
  flake-parts-lib,
  config,
  inputs,
  self,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    filterAttrs
    ;

  inherit (flake-parts-lib) mkPerSystemOption;

  impLib = import ./.;

  cfg = config.imp;

  # Build tree from a directory, calling each file with args
  buildTree =
    dir: args:
    if builtins.pathExists dir then
      impLib.treeWith lib (f: if builtins.isFunction f then f args else f) dir
    else
      { };

  # Determine if a name is a perSystem output
  isPerSystemDir = name: name == cfg.perSystemDir;

  # Get flake-level outputs (everything except perSystem dir)
  flakeTree =
    if cfg.src == null then
      { }
    else
      let
        fullTree = buildTree cfg.src (
          {
            inherit lib self inputs;
          }
          // cfg.args
        );
      in
      filterAttrs (name: _: !isPerSystemDir name) fullTree;

in
{
  options = {
    imp = {
      src = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory containing flake outputs to import";
      };

      args = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
        description = "Extra arguments passed to all imported files";
      };

      perSystemDir = mkOption {
        type = types.str;
        default = "perSystem";
        description = "Subdirectory name for per-system outputs";
      };
    };

    perSystem = mkPerSystemOption (
      { ... }:
      {
        options.imp = {
          args = mkOption {
            type = types.attrsOf types.unspecified;
            default = { };
            description = "Extra per-system arguments passed to imported files";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg.src != null) {
    # Flake-level outputs
    flake = flakeTree;

    # Per-system outputs
    perSystem =
      {
        pkgs,
        system,
        self',
        inputs',
        config,
        ...
      }:
      let
        perSystemPath = cfg.src + "/${cfg.perSystemDir}";
        perSystemArgs = {
          inherit
            lib
            pkgs
            system
            self
            self'
            inputs
            inputs'
            ;
        }
        // cfg.args
        // config.imp.args;
      in
      buildTree perSystemPath perSystemArgs;
  };
}
