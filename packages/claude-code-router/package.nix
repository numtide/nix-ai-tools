{
  lib,
  stdenv,
  fetchzip,
  nodejs_20,
}:

stdenv.mkDerivation rec {
  pname = "claude-code-router";
  version = "1.0.35";

  src = fetchzip {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-0TFflhZEESO6cwLiK0UZ542bcCw1LVnH30jkH3k/528=";
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

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Use Claude Code without an Anthropics account and route it to another LLM provider";
    homepage = "https://github.com/musistudio/claude-code-router";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "ccr";
  };
}
