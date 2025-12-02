{
  pkgs,
  treefmt-nix,
  ...
}:
let
  treefmtEval = treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";
    programs.nixfmt.enable = true;
    settings.global.excludes = [ "tests/fixtures/*" ];
  };
in
treefmtEval.config.build.wrapper
