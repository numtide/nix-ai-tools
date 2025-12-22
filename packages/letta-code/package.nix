{
  lib,
  stdenv,
  fetchzip,
  nodejs,
}:

stdenv.mkDerivation rec {
  pname = "letta-code";
  version = "0.7.4";

  src = fetchzip {
    url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
    hash = "sha256-WdT7cgSDdo9U6fJCGkkWtcBoPAyz2/kPpUymt/vOvU0=";
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
