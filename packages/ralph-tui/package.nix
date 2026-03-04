{
  lib,
  flake,
  stdenv,
  bun2nix,
  bun,
  fetchFromGitHub,
  makeWrapper,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation {
  pname = "ralph-tui";
  inherit version;

  src = fetchFromGitHub {
    owner = "subsy";
    repo = "ralph-tui";
    rev = "v${version}";
    inherit hash;
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
