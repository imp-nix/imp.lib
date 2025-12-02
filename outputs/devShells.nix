{
  pkgs,
  nix-unit,
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
{
  default = pkgs.mkShell {
    packages = [ nix-unit.packages.${pkgs.system}.default ];
    inputsFrom = [ treefmtEval.config.build.devShell ];
  };
}
