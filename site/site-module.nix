# Site module for building the Imp documentation with mdbook
{ pkgs, ... }:
{
  packages.docs = pkgs.stdenvNoCC.mkDerivation {
    name = "imp-docs";
    src = ./.;
    nativeBuildInputs = [ pkgs.mdbook ];
    buildPhase = ''
      runHook preBuild
      mdbook build --dest-dir $out
      runHook postBuild
    '';
    dontInstall = true;
  };

  apps.docs = {
    type = "app";
    program =
      let
        opener = if pkgs.stdenv.isDarwin then "open" else "xdg-open";
      in
      toString (
        pkgs.writeShellScript "open-docs" ''
          ${pkgs.mdbook}/bin/mdbook serve ${./site} &
          sleep 1
          ${opener} http://localhost:3000
          wait
        ''
      );
    meta.description = "Serve the Imp documentation locally with live reload";
  };

  apps.build-docs = {
    type = "app";
    program = toString (
      pkgs.writeShellScript "build-docs" ''
        ${pkgs.mdbook}/bin/mdbook build ${./site} --dest-dir ./docs
        echo "Documentation built to ./docs"
      ''
    );
    meta.description = "Build the Imp documentation";
  };
}
