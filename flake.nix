{
  description = "A Nix library for organizing flakes with directory-based imports, named module registries, and automatic input collection.
";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    imp-fmt.url = "github:imp-nix/imp.fmt";
    imp-fmt.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    imp-fmt.inputs.treefmt-nix.follows = "treefmt-nix";

    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.treefmt-nix.follows = "treefmt-nix";
    nix-unit.inputs.flake-parts.follows = "flake-parts";

    docgen.url = "github:imp-nix/imp.docgen";
    docgen.inputs.nixpkgs.follows = "nixpkgs";
    docgen.inputs.treefmt-nix.follows = "treefmt-nix";
    docgen.inputs.nix-unit.follows = "nix-unit";
    docgen.inputs.imp-fmt.follows = "imp-fmt";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      nix-unit,
      treefmt-nix,
      imp-fmt,
      docgen,
      ...
    }:
    let
      imp = import ./src;
      lib = nixpkgs.lib;
      flakeModule = import ./src/flakeModule.nix;
      formatterLib = imp-fmt.lib;
    in
    {
      tests = import ./tests { inherit lib; };

      __functor = imp.__functor;
      __config = imp.__config;
      withLib = imp.withLib;
      addPath = imp.addPath;
      addAPI = imp.addAPI;
      new = imp.new;

      tree = imp.tree;
      treeWith = imp.treeWith;
      configTree = imp.configTree;
      configTreeWith = imp.configTreeWith;

      collectInputs = imp.collectInputs;
      formatInputs = imp.formatInputs;
      formatFlake = imp.formatFlake;
      collectAndFormatFlake = imp.collectAndFormatFlake;

      flakeModules = {
        default = flakeModule;
        docs = ./src/flakeModules/docs.nix;
        visualize = ./src/flakeModules/visualize.nix;
      };

      inherit formatterLib;
    }
    // flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        flakeModule
        ./src/flakeModules/docs.nix
        ./src/flakeModules/visualize.nix
      ];

      imp = {
        src = ./outputs;
        args = {
          inherit
            self
            nixpkgs
            nix-unit
            treefmt-nix
            imp-fmt
            ;
        };
        registry.src = ./src;

        docs = {
          manifest = ./docs/manifest.nix;
          srcDir = ./src;
          siteDir = ./docs;
          name = "imp";
          anchorPrefix = "imp";
          optionsModule = ./src/options-schema.nix;
          optionsPrefix = "imp.";
        };
      };
    };
}
