{
  self,
  pkgs,
  system,
  nixpkgs,
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
  formatting = treefmtEval.config.build.check self;
  nix-unit =
    pkgs.runCommand "nix-unit-tests"
      {
        nativeBuildInputs = [ nix-unit.packages.${system}.default ];
      }
      ''
        export HOME=$TMPDIR
        nix-unit --expr 'import ${self}/tests { lib = import ${nixpkgs}/lib; }'
        touch $out
      '';
}
