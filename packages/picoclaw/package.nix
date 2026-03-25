{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  go_1_25,
  unpinGoModVersionHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildGoModule.override { go = go_1_25; } rec {
  pname = "picoclaw";
  version = "0.2.3";

  src = fetchFromGitHub {
    owner = "sipeed";
    repo = "picoclaw";
    tag = "v${version}";
    hash = "sha256-CnwfnYl7hciCbgC0P/I9anGdmrzpRalutGmPAJ6H7NI=";
  };

  vendorHash = "sha256-3MjBLklUpMTcz5/tW7Lr6d4wJ1x7ylFiEZkyeJI0CUA=";

  nativeBuildInputs = [ unpinGoModVersionHook ];

  postPatch = ''
    # go:embed in cmd/picoclaw/internal/onboard/command.go expects a workspace
    # directory copied there by go:generate which doesn't run during nix builds
    cp -r workspace cmd/picoclaw/internal/onboard/workspace
  '';

  subPackages = [ "cmd/picoclaw" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/sipeed/picoclaw/pkg/config.Version=${version}"
  ];

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  versionCheckProgramArg = "version";
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Assistants";

  meta = {
    description = "Tiny, fast, and deployable anywhere — automate the mundane, unleash your creativity";
    homepage = "https://picoclaw.io";
    changelog = "https://github.com/sipeed/picoclaw/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ commandodev ];
    mainProgram = "picoclaw";
    platforms = lib.platforms.unix;
  };
}
