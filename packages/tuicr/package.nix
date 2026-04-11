{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  libgit2,
  git,
  python3Packages,
  flake,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tuicr";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "agavra";
    repo = "tuicr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Hu58R7LOsTSArZuqrmH7G5NwJI8NnSxMXbdqCqbxIxs=";
  };

  cargoHash = "sha256-tuYlErRt0ifKcAWWHy+aTwwss8Y6PJedpiKMJZUC6Yo=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libgit2
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    git
    python3Packages.pexpect
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    # tuicr has no --version flag; verify the binary runs and produces expected output
    python3 ${./check-tuicr.py} $out/bin/tuicr
    runHook postInstallCheck
  '';

  passthru.category = "Code Review";

  meta = {
    description = "Review AI-generated diffs like a GitHub pull request, right from your terminal";
    homepage = "https://github.com/agavra/tuicr";
    changelog = "https://github.com/agavra/tuicr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "tuicr";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    maintainers = with flake.lib.maintainers; [ ypares ];
  };
})
