{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;
in
buildNpmPackage {
  pname = "cc-sdd";
  inherit version npmDepsHash;

  src = fetchFromGitHub {
    owner = "gotalab";
    repo = "cc-sdd";
    rev = "v${version}";
    inherit hash;
  };

  sourceRoot = "source/tools/cc-sdd";

  # Build with tsc
  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/cc-sdd

    cp -r dist $out/lib/cc-sdd/
    cp -r templates $out/lib/cc-sdd/
    cp package.json $out/lib/cc-sdd/

    chmod +x $out/lib/cc-sdd/dist/cli.js

    substituteInPlace $out/lib/cc-sdd/dist/cli.js \
      --replace-fail "#!/usr/bin/env node" "#!${bun}/bin/bun"

    ln -s $out/lib/cc-sdd/dist/cli.js $out/bin/cc-sdd

    runHook postInstall
  '';

  dontNpmBuild = false;

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Spec-driven development framework for AI coding agents";
    homepage = "https://github.com/gotalab/cc-sdd";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "cc-sdd";
    platforms = platforms.all;
  };
}
