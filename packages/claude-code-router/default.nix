{ pkgs, perSystem }:

let
  nodejs = pkgs.nodejs_20;
in
pkgs.stdenv.mkDerivation rec {
  pname = "claude-code-router";
  version = "1.0.19";

  src = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-a24R5jqt03cjoaQmGPIRIO35DbIlXlmRAwAwY8Ifngw=";
  };

  nativeBuildInputs = [ nodejs ];

  installPhase = ''
    runHook preInstall

    # The npm package already contains built files
    mkdir -p $out/bin
    cp $src/dist/cli.js $out/bin/ccr
    chmod +x $out/bin/ccr

    # Replace the shebang with the correct node path
    substituteInPlace $out/bin/ccr \
      --replace-quiet "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    # Install the WASM file in the same directory as the CLI
    cp $src/dist/tiktoken_bg.wasm $out/bin/

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = with pkgs.lib; {
    description = "Use Claude Code without an Anthropics account and route it to another LLM provider";
    homepage = "https://github.com/musistudio/claude-code-router";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "ccr";
  };
}
