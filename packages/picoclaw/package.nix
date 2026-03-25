{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  unpinGoModVersionHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildGoModule rec {
  pname = "picoclaw";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "sipeed";
    repo = "picoclaw";
    tag = "v${version}";
    hash = "sha256-CSAUlCe/g22rzbOx3xNTMFRIOwp/+ezCMRCjNRcQeZ0=";
  };

  vendorHash = "sha256-ocLRiFZs2OnKM7C2/cUafpC8LIRCLybXG0ln8n9ZXr4=";

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
