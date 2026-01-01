/**
  Documentation generation for imp.
*/
{
  pkgs,
  lib,
  docgen,
}:
let
  optionsJson = docgen.lib.optionsToJson {
    optionsModule = ../src/options-schema.nix;
    prefix = "imp.";
  };
  optionsJsonFile = pkgs.writeText "imp-options.json" optionsJson;

in
docgen.mkDocgen {
  inherit pkgs lib;
  name = "imp";
  manifest = ./manifest.nix;
  srcDir = ../src;
  siteDir = ./.;
  optionsJson = optionsJsonFile;
  anchorPrefix = "imp";
}
