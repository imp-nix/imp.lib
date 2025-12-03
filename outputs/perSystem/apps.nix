{
  pkgs,
  system,
  nix-unit,
  nixpkgs,
  self,
  lib,
  ...
}:
let
  visualizeLib = import ../../src/visualize.nix { inherit lib; };
in
{
  tests = {
    type = "app";
    meta.description = "Run imp unit tests";
    program = toString (
      pkgs.writeShellScript "run-tests" ''
        ${nix-unit.packages.${system}.default}/bin/nix-unit --flake .#tests
      ''
    );
  };

  /*
    Visualize registry dependencies as an interactive HTML graph.

    Usage:
      nix run .#visualize -- <path-to-nix-directory> [--format=html|json]

    Examples:
      nix run .#visualize -- ./nix > deps.html

    The tool scans the directory for a registry structure and analyzes
    all modules for cross-references.

    Note: This standalone version requires a path argument and does runtime
    evaluation. For pre-configured visualization of your own flake's registry,
    use `nix run .#imp-vis` (available when using the imp flakeModule
    with registry.src set).
  */
  visualize = {
    type = "app";
    meta.description = "Visualize imp registry dependencies (standalone)";
    program = toString (
      visualizeLib.mkVisualizeScript {
        inherit pkgs;
        impSrc = self.sourceInfo or self;
        nixpkgsFlake = nixpkgs;
        name = "imp-vis";
      }
    );
  };
}
