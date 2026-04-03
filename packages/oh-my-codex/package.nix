{
  lib,
  flake,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  rustPlatform,
  makeWrapper,
  nodejs,
  codex,
  versionCheckHook,
}:

let
  pname = "oh-my-codex";
  version = "0.11.12";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-codex";
    rev = "v${version}";
    hash = "sha256-VcaAh0J1Iloxj89R2/UVy1NJNLkD3rK8GUTtYU0nSRI=";
  };

  cargoHash = "sha256-BuA54daR1pIaVEkOVmYk6B54gVl3Flu4sVtWKZnsuHo=";

  nodePlatformMap = {
    x86_64-linux = "linux";
    aarch64-linux = "linux";
    x86_64-darwin = "darwin";
    aarch64-darwin = "darwin";
  };

  nodeArchMap = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
    x86_64-darwin = "x64";
    aarch64-darwin = "arm64";
  };

  system = stdenv.hostPlatform.system;
  nodePlatform = nodePlatformMap.${system} or (throw "Unsupported system for ${pname}: ${system}");
  nodeArch = nodeArchMap.${system} or (throw "Unsupported architecture for ${pname}: ${system}");

  mkNativeBinary =
    cargoPackage: binaryName:
    rustPlatform.buildRustPackage {
      pname = binaryName;
      inherit version src cargoHash;

      cargoBuildFlags = [
        "--package"
        cargoPackage
      ];

      cargoInstallFlags = [
        "--path"
        "."
        "--bin"
        binaryName
      ];

      doCheck = false;

      meta = with lib; {
        description = "Native sidecar for ${pname}";
        homepage = "https://github.com/Yeachan-Heo/oh-my-codex";
        changelog = "https://github.com/Yeachan-Heo/oh-my-codex/releases/tag/v${version}";
        license = licenses.mit;
        sourceProvenance = with sourceTypes; [ fromSource ];
        maintainers = with flake.lib.maintainers; [ smdex ];
        mainProgram = binaryName;
        platforms = platforms.unix;
      };
    };

  exploreHarness = mkNativeBinary "omx-explore-harness" "omx-explore-harness";
  sparkShell = mkNativeBinary "omx-sparkshell" "omx-sparkshell";
in
buildNpmPackage (finalAttrs: {
  inherit
    npmConfigHook
    pname
    version
    src
    ;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-or53akxqVQt7zTghO/i4Yv7uHDV7l7no0cp5Hg8QY9Q=";
    fetcherVersion = 2;
  };

  makeCacheWritable = true;
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    root=$out/share/oh-my-codex
    mkdir -p $out/bin $root $root/src

    cp -r dist skills prompts templates package.json Cargo.toml Cargo.lock crates $root/
    cp -r src/scripts $root/src/

    npm prune --omit=dev
    cp -r node_modules $root/
    patchShebangs $root

    install -Dm755 ${exploreHarness}/bin/omx-explore-harness \
      $root/bin/omx-explore-harness

    cat > $root/bin/omx-explore-harness.meta.json <<EOF
    {
      "binaryName": "omx-explore-harness",
      "platform": "${nodePlatform}",
      "arch": "${nodeArch}",
      "strategy": "nix-packaged"
    }
    EOF

    install -Dm755 ${sparkShell}/bin/omx-sparkshell \
      $root/bin/native/${nodePlatform}-${nodeArch}/omx-sparkshell

    makeWrapper ${lib.getExe nodejs} $out/bin/omx \
      --add-flags "$root/dist/cli/omx.js" \
      --prefix PATH : ${lib.makeBinPath [ codex ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];

  passthru = {
    category = "AI Coding Agents";
    native = {
      inherit exploreHarness sparkShell;
    };
  };

  meta = with lib; {
    description = "Multi-agent orchestration layer for OpenAI Codex CLI";
    homepage = "https://github.com/Yeachan-Heo/oh-my-codex";
    changelog = "https://github.com/Yeachan-Heo/oh-my-codex/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "omx";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
})
