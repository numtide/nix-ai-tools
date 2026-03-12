{
  lib,
  flake,
  stdenv,
  bun2nix,
  bun,
  fetchFromGitHub,
  makeWrapper,
  autoPatchelfHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation {
  pname = "oh-my-opencode";
  inherit version;

  src = fetchFromGitHub {
    owner = "code-yeongyu";
    repo = "oh-my-openagent";
    tag = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nix.hook
    bun
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # postinstall downloads platform-specific pre-compiled binaries,
  # prepare runs the build — we handle both ourselves
  dontRunLifecycleScripts = true;
  dontUseBunBuild = true;
  dontUseBunInstall = true;

  # @ast-grep/napi ships binaries for multiple platforms;
  # ignore missing musl libc on glibc systems
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  buildPhase = ''
    runHook preBuild

    # Build the library and CLI bundles
    bun build src/index.ts --outdir dist --target bun --format esm --external @ast-grep/napi
    bun build src/cli/index.ts --outdir dist/cli --target bun --format esm --external @ast-grep/napi

    # Generate the config schema (non-fatal if it fails)
    bun run build:schema || true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/oh-my-opencode $out/bin

    cp -r dist node_modules package.json $out/lib/oh-my-opencode/

    makeWrapper ${bun}/bin/bun $out/bin/oh-my-opencode \
      --add-flags "run $out/lib/oh-my-opencode/dist/cli/index.js"

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "The Best AI Agent Harness - Multi-Model Orchestration for OpenCode";
    homepage = "https://github.com/code-yeongyu/oh-my-openagent";
    changelog = "https://github.com/code-yeongyu/oh-my-openagent/releases/tag/v${version}";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ titaniumtown ];
    mainProgram = "oh-my-opencode";
    platforms = platforms.unix;
  };
}
