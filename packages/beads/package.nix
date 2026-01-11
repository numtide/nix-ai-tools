{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.47.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-p7l4wla+8vQqBUeNyoGKWhBQO8m53A4UNSghQQCvk2A=";
  };

  vendorHash = "sha256-pY5m5ODRgqghyELRwwxOr+xlW41gtJWLXaW53GlLaFw=";

  subPackages = [ "cmd/bd" ];

  doCheck = false;

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "A distributed issue tracker designed for AI-supervised coding workflows";
    homepage = "https://github.com/steveyegge/beads";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "bd";
    # TODO: aarch64-linux fails with "go: no such tool 'link'" error during build
    # This appears to be a Go 1.24 toolchain issue on aarch64-linux in nixpkgs.
    # Need to investigate if using a different Go version or build flags can fix this.
    # Upstream provides pre-built ARM64 binaries, so platform support exists.
    # See: https://github.com/numtide/llm-agents.nix/pull/XXX
    broken = lib.elem stdenv.hostPlatform.system [ "aarch64-linux" ];
  };
}
