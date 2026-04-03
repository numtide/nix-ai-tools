{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  dolt,
  go-bin,
  icu,
  pkg-config,
  versionCheckHook,
}:

buildGoModule.override { go = go-bin; } rec {
  pname = "beads";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-D2jShGpkOWKx9aRmRvV5bmV8t0/Y2eAE8q0m54QrRN0=";
  };

  vendorHash = "sha256-7DJgqJX2HDa9gcGD8fLNHLIXvGAEivYeDYx3snCUyCE=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    icu
  ];

  env.CGO_ENABLED = "1";

  subPackages = [ "cmd/bd" ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/bd \
      --prefix PATH : ${lib.makeBinPath [ dolt ]}
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "A distributed issue tracker designed for AI-supervised coding workflows";
    homepage = "https://github.com/steveyegge/beads";
    changelog = "https://github.com/steveyegge/beads/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "bd";
    platforms = platforms.unix;
  };
}
