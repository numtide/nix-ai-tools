{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  dolt,
  go-bin,
  versionCheckHook,
}:

buildGoModule.override { go = go-bin; } rec {
  pname = "beads";
  version = "0.60.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-z3EDtaBHB3ltPRT7vuBFURD7UwgAJBXAPozRnkjejeU=";
  };

  vendorHash = "sha256-1BJsEPP5SYZFGCWHLn532IUKlzcGDg5nhrqGWylEHgY=";

  nativeBuildInputs = [
    makeWrapper
  ];

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
