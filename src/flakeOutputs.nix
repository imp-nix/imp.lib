# Builds flake outputs from directory structure with automatic per-system handling
#
# Files that accept `pkgs` or `system` in their arguments are automatically
# wrapped with lib.genAttrs for all specified systems.
#
# Example:
#   # outputs/packages.nix - receives pkgs, auto-wrapped per-system
#   { pkgs, ... }: { hello = pkgs.hello; }
#
#   # outputs/nixosConfigurations/foo.nix - no pkgs/system, called directly
#   { lib, ... }: lib.nixosSystem { ... }
#
{
  lib,
  systems,
  pkgsFor,
  args,
  treef ? import,
  filterf ? _: true,
}:
let
  # Check if a function wants per-system handling
  wantsPerSystem =
    f:
    let
      fArgs = builtins.functionArgs f;
    in
    fArgs ? pkgs || fArgs ? system;

  # Wrap a function for per-system evaluation
  wrapPerSystem =
    f:
    lib.genAttrs systems (
      system:
      f (
        args
        // {
          inherit system;
          pkgs = pkgsFor system;
        }
      )
    );

  # Process an imported file - detect and wrap if needed
  processImport =
    imported:
    let
      f = if builtins.isFunction imported then imported else (_: imported);
      needsPerSystem = builtins.isFunction imported && wantsPerSystem imported;
    in
    if needsPerSystem then wrapPerSystem f else f args;

  # Build tree with our processing
  buildTree = import ./tree.nix {
    inherit lib filterf;
    treef = path: processImport (treef path);
  };
in
buildTree
