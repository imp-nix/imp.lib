{
  pkgs,
  lib,
  treefmt-nix,
  ...
}:
let
  mdformat = pkgs.mdformat.withPlugins (
    ps: with ps; [
      mdformat-gfm
      mdformat-frontmatter
      mdformat-footnote
    ]
  );
  treefmtEval = treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";
    programs.nixfmt.enable = true;
    settings.global.excludes = [ "tests/fixtures/*" ];
    settings.formatter.mdformat = {
      command = lib.getExe mdformat;
      includes = [ "*.md" ];
    };
  };
in
treefmtEval.config.build.wrapper
