{
  pkgs,
  lib,
  docgen,
  ...
}:
let
  # Import shared docgen utilities
  dg = import ./_docgen.nix { inherit pkgs lib docgen; };
in
{
  # Built documentation site
  docs = dg.docs;

  # Expose API reference for debugging
  api-reference = dg.apiReference;
}
