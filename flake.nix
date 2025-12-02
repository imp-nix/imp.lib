{
  description = "Recursively import Nix modules from a directory";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-unit.url = "github:nix-community/nix-unit";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nix-unit,
      treefmt-nix,
      ...
    }:
    let
      imp = import ./src;
      lib = nixpkgs.lib;
    in
    {
      tests = import ./tests { inherit lib; };

      # Export imp as a callable functor with essential methods
      # Avoid exporting self-referential attrs (leafs, filter, map, etc.)
      __functor = imp.__functor;
      __config = imp.__config; # Required for __functor to work
      withLib = imp.withLib;
      addPath = imp.addPath;
      addAPI = imp.addAPI;
      new = imp.new;

      # High-level tree operations (require withLib first)
      tree = imp.tree;
      treeWith = imp.treeWith;
      configTree = imp.configTree;
      configTreeWith = imp.configTreeWith;
      flakeOutputs = imp.flakeOutputs;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        args = {
          inherit
            self
            pkgs
            nixpkgs
            nix-unit
            treefmt-nix
            ;
        };
        # Dogfooding: use .treeWith to load per-system outputs from ./outputs
        outputs = imp.treeWith lib (f: f args) ./outputs;
      in
      outputs
    );
}
