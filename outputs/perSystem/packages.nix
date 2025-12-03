{ pkgs, ... }:
let
  siteDir = ../../site;
in
{
  docs = pkgs.stdenvNoCC.mkDerivation {
    name = "imp-docs";
    src = siteDir;
    nativeBuildInputs = [ pkgs.mdbook ];
    buildPhase = ''
      runHook preBuild
      mdbook build --dest-dir $out
      runHook postBuild
    '';
    dontInstall = true;
  };
}
