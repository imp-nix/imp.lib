/*
  Flake-parts module for imp.

  Automatically loads flake outputs from a directory structure.
  Directory structure maps directly to flake-parts options:

    outputs/
      perSystem/           -> perSystem options (receives pkgs, system, etc.)
        packages.nix       -> perSystem.packages
        apps.nix           -> perSystem.apps
        devShells.nix      -> perSystem.devShells
      nixosConfigurations/ -> flake.nixosConfigurations
      overlays.nix         -> flake.overlays
      systems.nix          -> systems (list of supported systems)

  Files receive standardized arguments matching flake-parts conventions:
    - perSystem files: { pkgs, lib, system, self, self', inputs, inputs', config, ... }
    - flake files: { lib, self, inputs, config, ... }
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
    mkEnableOption
    types
    filterAttrs
    ;

  inherit (flake-parts-lib) mkPerSystemOption;

  impLib = import ./.;
  registryLib = import ./registry.nix { inherit lib; };
  migrateLib = import ./migrate.nix { inherit lib; };

  cfg = config.imp;

  # Build the registry from configured sources
  registry =
    if cfg.registry.src == null then
      { }
    else
      let
        autoRegistry = registryLib.buildRegistry cfg.registry.src;
      in
      lib.recursiveUpdate autoRegistry cfg.registry.modules;

  # Bound imp instance with lib for passing to modules
  imp = impLib.withLib lib;

  # Build tree from a directory, calling each file with args.
  # Handles both functions and attrsets with __functor.
  buildTree =
    dir: args:
    if builtins.pathExists dir then
      impLib.treeWith lib (f: if builtins.isFunction f || f ? __functor then f args else f) dir
    else
      { };

  # Reserved directory/file names that have special handling
  isSpecialEntry = name: name == cfg.perSystemDir || name == "systems";

  # Use nixpkgs lib when available (has nixosSystem, etc.), fallback to flake-parts lib
  # This ensures lib.nixosSystem works in output files
  nixpkgsLib = inputs.nixpkgs.lib or lib;

  # Standard flake-level args (mirrors flake-parts module args)
  flakeArgs = {
    lib = nixpkgsLib;
    inherit
      self
      inputs
      config
      imp
      ;
    # Allow access to top-level options for introspection
    inherit (config) systems;
    ${cfg.registry.name} = registry;
  }
  // cfg.args;

  # Get flake-level outputs (everything except special entries)
  flakeTree =
    if cfg.src == null then
      { }
    else
      let
        fullTree = buildTree cfg.src flakeArgs;
      in
      filterAttrs (name: _: !isSpecialEntry name) fullTree;

  # Check for systems.nix in src directory
  systemsFile = cfg.src + "/systems.nix";
  hasSystemsFile = cfg.src != null && builtins.pathExists systemsFile;
  systemsFromFile =
    if hasSystemsFile then
      let
        imported = import systemsFile;
      in
      if builtins.isFunction imported then imported flakeArgs else imported
    else
      null;

  # Flake file generation
  flakeFileCfg = cfg.flakeFile;
  collectedInputs = if flakeFileCfg.enable then impLib.collectInputs cfg.src else { };
  generatedFlakeContent =
    if flakeFileCfg.enable then
      impLib.formatFlake {
        inherit (flakeFileCfg)
          description
          coreInputs
          outputsFile
          header
          ;
        inherit collectedInputs;
      }
    else
      "";

in
{
  options = {
    imp = {
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
          example = lib.literalExpression ''
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
          example = lib.literalExpression ''
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
          example = lib.literalExpression ''
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
          example = lib.literalExpression ''
            [ ./nix/outputs ./nix/flake ]
          '';
        };
      };

      flakeFile = {
        enable = mkEnableOption "flake.nix generation from __inputs declarations";

        path = mkOption {
          type = types.path;
          default = self + "/flake.nix";
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
          example = lib.literalExpression ''
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

    perSystem = mkPerSystemOption (
      { ... }:
      {
        options.imp = {
          args = mkOption {
            type = types.attrsOf types.unspecified;
            default = { };
            description = "Extra per-system arguments passed to imported files.";
          };
        };
      }
    );
  };

  config = lib.mkMerge [
    # Systems from file (if present)
    (lib.mkIf (systemsFromFile != null) {
      systems = lib.mkDefault systemsFromFile;
    })

    # Main imp config
    (lib.mkIf (cfg.src != null) {
      flake = flakeTree;

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
              imp
              ;
            ${cfg.registry.name} = registry;
          }
          // cfg.args
          // config.imp.args;
        in
        buildTree perSystemPath perSystemArgs;
    })

    # Flake file generation outputs
    (lib.mkIf flakeFileCfg.enable {
      perSystem =
        { pkgs, ... }:
        {
          /*
            Regenerate flake.nix from __inputs declarations.

            Files can declare inputs inline:

              # With __functor (when file needs args like pkgs, inputs):
              {
                __inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
                __functor = _: { pkgs, inputs, ... }:
                  inputs.treefmt-nix.lib.evalModule pkgs { ... };
              }

              # Without __functor (static data that declares inputs):
              {
                __inputs.foo.url = "github:owner/foo";
                someKey = "value";
              }

            Run: nix run .#imp-flake
          */
          apps.imp-flake = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "imp-flake" ''
                printf '%s' ${lib.escapeShellArg generatedFlakeContent} > flake.nix
                echo "Generated flake.nix"
              ''
            );
            meta.description = "Regenerate flake.nix from __inputs declarations";
          };

          checks.flake-up-to-date =
            pkgs.runCommand "flake-up-to-date"
              {
                expected = generatedFlakeContent;
                actual = builtins.readFile flakeFileCfg.path;
                passAsFile = [
                  "expected"
                  "actual"
                ];
              }
              ''
                if diff -u "$expectedPath" "$actualPath"; then
                  echo "flake.nix is up-to-date"
                  touch $out
                else
                  echo ""
                  echo "ERROR: flake.nix is out of date!"
                  echo "Run 'nix run .#imp-flake' to regenerate it."
                  exit 1
                fi
              '';
        };
    })

    # Registry migration outputs
    (lib.mkIf (cfg.registry.src != null) {
      perSystem =
        { pkgs, ... }:
        let
          migratePaths =
            if cfg.registry.migratePaths != [ ] then
              cfg.registry.migratePaths
            else if cfg.src != null then
              [ cfg.src ]
            else
              [ ];

          migration = migrateLib.detectRenames {
            inherit registry;
            paths = migratePaths;
            astGrep = "${pkgs.ast-grep}/bin/ast-grep";
            registryName = cfg.registry.name;
          };

          analyzeLib = import ./analyze.nix { inherit lib; };
          visualizeLib = import ./visualize.nix { inherit lib; };
          graph = analyzeLib.analyzeRegistry { inherit registry; };
        in
        {
          /*
            Detect registry renames and generate fix commands.

             When directories are renamed, registry paths change. This app:
             1. Scans files for registry.X.Y patterns
             2. Compares against current registry to find broken references
             3. Suggests mappings from old names to new names
             4. Uses ast-grep for AST-aware replacements

             Run: nix run .#imp-registry
          */
          apps.imp-registry = {
            type = "app";
            program = toString (pkgs.writeShellScript "imp-registry" migration.script);
            meta.description = "Detect and fix registry path renames";
          };
          /*
            Visualize registry dependencies as a graph.

            Analyzes the registry and outputs a dependency graph showing
            how modules reference each other via registry paths.

            Run: nix run .#imp-vis [--format=dot|ascii|json]
          */
          apps.imp-vis = {
            type = "app";
            program = toString (visualizeLib.mkVisualizeScript { inherit pkgs graph; });
            meta.description = "Visualize registry dependencies";
          };
        };
    })
  ];
}
