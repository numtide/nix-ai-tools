{
  lib,
  flake,
  stdenv,
  bun2nix,
  bun,
  fetchFromGitHub,
  makeWrapper,
}:

stdenv.mkDerivation {
  pname = "ralph-tui";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "subsy";
    repo = "ralph-tui";
    rev = "4477972cc6959c8e396536cf2dc05818e3c25e05";
    hash = "sha256-xwdrmar8YnnkzuU6H229VHZDXSkQiF1kPbCATAYSS5I=";
  };

  nativeBuildInputs = [
    bun2nix.hook
    makeWrapper
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # @opentui/core uses top-level await and dynamic import() for native FFI,
  # which prevents bun build --compile. Build from source with externals
  # and wrap with bun runtime instead.
  dontUseBunBuild = true;
  dontUseBunInstall = true;

  buildPhase = ''
    runHook preBuild
    bun run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/ralph-tui
    cp -r dist node_modules package.json $out/lib/ralph-tui/
    mkdir -p $out/bin
    makeWrapper ${bun}/bin/bun $out/bin/ralph-tui \
      --add-flags "run $out/lib/ralph-tui/dist/cli.js"
    runHook postInstall
  '';

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "AI Agent Loop Orchestrator TUI";
    homepage = "https://github.com/subsy/ralph-tui";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "ralph-tui";
    platforms = platforms.unix;
  };
}
