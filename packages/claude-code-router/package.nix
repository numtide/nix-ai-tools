{
  lib,
  stdenv,
  fetchzip,
  nodejs_20,
}:

stdenv.mkDerivation rec {
  pname = "claude-code-router";
  version = "1.0.66";

  src = fetchzip {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-x2zouqP24Mk+JrKBU2QNwideF1F0BxAkindxj0leH+4=";
  };

  nativeBuildInputs = [ nodejs_20 ];

  installPhase = ''
    runHook preInstall

    # The npm package already contains built files
    mkdir -p $out/bin
    cp $src/dist/cli.js $out/bin/ccr
    chmod +x $out/bin/ccr

    # Replace the shebang with the correct node path
    substituteInPlace $out/bin/ccr \
      --replace-quiet "#!/usr/bin/env node" "#!${nodejs_20}/bin/node"

    # Install the WASM file in the same directory as the CLI
    cp $src/dist/tiktoken_bg.wasm $out/bin/

    runHook postInstall
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Use Claude Code without an Anthropics account and route it to another LLM provider";
    homepage = "https://github.com/musistudio/claude-code-router";
    changelog = "https://github.com/musistudio/claude-code-router/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ];
    mainProgram = "ccr";
    platforms = platforms.all;
  };
}
