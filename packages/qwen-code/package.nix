{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  git,
  ripgrep,
  pkg-config,
  glib,
  libsecret,
  darwinOpenptyHook,
  clang_20,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  versionCheckHook,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "qwen-code";
  version = "0.10.3";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-obfom9f05lbrgKsAbmn9ayWeSd8n1dRxLHDJkqOqgsk=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-ZWkQyuX4t41qvW1+QbX/ODH2Srby1hkbxt/v2NHtLhs=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  nativeBuildInputs = [
    pkg-config
    git
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    clang_20 # Works around node-addon-api constant expression issue with clang 21+ (keytar)
    darwinOpenptyHook # Fixes node-pty openpty/forkpty build issue
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  buildPhase = ''
    runHook preBuild

    npm run generate
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    # Install production dependencies only
    npm prune --production
    cp -r node_modules $out/share/qwen-code/
    # Remove broken symlinks that cause issues in Nix environment
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli.js $out/bin/qwen

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [
      zimbatm
      lonerOrz
    ];
    platforms = lib.platforms.all;
    mainProgram = "qwen";
  };
})
