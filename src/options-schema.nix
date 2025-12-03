/*
  Shared options schema for imp.

  This module defines the options schema used by:
  - flakeModule.nix (runtime module)
  - Documentation generation (packages.nix, apps.nix)

  The schema is defined as a function that takes lib and optional self,
  returning a module with options. This allows it to be used both in
  flake-parts context and in lib.evalModules for documentation.
*/
{
  lib,
  # Optional: only available in flake-parts context
  self ? null,
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    literalExpression
    ;

  # Default path uses self if available, otherwise a placeholder
  defaultFlakePath = if self != null then self + "/flake.nix" else "/path/to/flake.nix";
in
{
  options.imp = {
    src = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Directory containing flake outputs to import.

        Structure maps to flake-parts semantics:
          outputs/
            perSystem/           -> perSystem.* (per-system outputs)
              packages.nix       -> perSystem.packages
              devShells.nix      -> perSystem.devShells
            nixosConfigurations/ -> flake.nixosConfigurations
            overlays.nix         -> flake.overlays
            systems.nix          -> systems (optional, overrides top-level)
      '';
    };

    args = mkOption {
      type = types.attrsOf types.unspecified;
      default = { };
      description = ''
        Extra arguments passed to all imported files.

        Flake files receive: { lib, self, inputs, config, imp, registry, ... }
        perSystem files receive: { pkgs, lib, system, self, self', inputs, inputs', imp, registry, ... }

        User-provided args take precedence over defaults.
      '';
    };

    perSystemDir = mkOption {
      type = types.str;
      default = "perSystem";
      description = ''
        Subdirectory name for per-system outputs.

        Files in this directory receive standard flake-parts perSystem args:
        { pkgs, lib, system, self, self', inputs, inputs', ... }
      '';
    };

    registry = {
      name = mkOption {
        type = types.str;
        default = "registry";
        description = ''
          Attribute name used to inject the registry into file arguments.

          Change this if "registry" conflicts with other inputs or arguments.
        '';
        example = literalExpression ''
          "impRegistry"
          # Then in files:
          # { impRegistry, ... }:
          # { imports = [ impRegistry.modules.home ]; }
        '';
      };

      src = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Root directory to scan for building the module registry.

          The registry maps directory structure to named modules.
          Files can then reference modules by name instead of path.
        '';
        example = literalExpression ''
          ./nix
          # Structure:
          #   nix/
          #     users/alice/     -> registry.users.alice
          #     modules/nixos/   -> registry.modules.nixos
          #
          # Usage in files:
          #   { registry, ... }:
          #   { imports = [ registry.modules.home ]; }
        '';
      };

      modules = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
        description = ''
          Explicit module name -> path mappings.
          These override auto-discovered modules from registry.src.
        '';
        example = literalExpression ''
          {
            specialModule = ./path/to/special.nix;
          }
        '';
      };

      migratePaths = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          Directories to scan for registry references when detecting renames.
          If empty, defaults to [ imp.src ] when registry.src is set.
        '';
        example = literalExpression ''
          [ ./nix/outputs ./nix/flake ]
        '';
      };
    };

    flakeFile = {
      enable = mkEnableOption "flake.nix generation from __inputs declarations";

      path = mkOption {
        type = types.path;
        default = defaultFlakePath;
        defaultText = literalExpression "self + \"/flake.nix\"";
        description = "Path to flake.nix file to generate/check.";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Flake description field.";
      };

      coreInputs = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
        description = ''
          Core inputs always included in flake.nix (e.g., nixpkgs, flake-parts).
        '';
        example = literalExpression ''
          {
            nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
            flake-parts.url = "github:hercules-ci/flake-parts";
          }
        '';
      };

      outputsFile = mkOption {
        type = types.str;
        default = "./outputs.nix";
        description = "Path to outputs file (relative to flake.nix).";
      };

      header = mkOption {
        type = types.str;
        default = "# Auto-generated by imp - DO NOT EDIT\n# Regenerate with: nix run .#imp-flake";
        description = "Header comment for generated flake.nix.";
      };
    };
  };
}
