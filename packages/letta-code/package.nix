{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  versionCheckHook,
}:

stdenv.mkDerivation rec {
  pname = "letta-code";
  version = "0.8.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
    hash = "sha256-eDocliCJLCyUkXTC8oUo+P/mNqRW7EmIxUf9OzU2hu8=";
  };

  nativeBuildInputs = [ nodejs ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/letta-code

    cp -r scripts skills vendor $out/lib/letta-code/

    mkdir -p $out/bin
    cp letta.js $out/bin/letta
    chmod +x $out/bin/letta

    substituteInPlace $out/bin/letta \
      --replace-fail "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];

  meta = with lib; {
    description = "Memory-first coding agent that learns and evolves across sessions";
    homepage = "https://github.com/letta-ai/letta-code";
    downloadPage = "https://www.npmjs.com/package/@letta-ai/letta-code";
    changelog = "https://github.com/letta-ai/letta-code/releases";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ vizid ];
    mainProgram = "letta";
    platforms = platforms.all;
  };
}
