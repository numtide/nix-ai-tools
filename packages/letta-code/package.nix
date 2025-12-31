{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation rec {
  pname = "letta-code";
  version = "0.10.4";

  src = fetchzip {
    url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
    hash = "sha256-Nt021AbUSnJPcsMUxYBWIcJrvtvO8UaraEdqOe76u88=";
  };

  nativeBuildInputs = [ nodejs ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/letta-code

    cp -r scripts skills vendor $out/lib/letta-code/

    install -m755 -D letta.js $out/bin/letta

    # Replace the shebang that tries to use bun or node with a direct node shebang
    sed -i '1,2c #!${nodejs}/bin/node' $out/bin/letta

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
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
