{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  dolt,
  unpinGoModVersionHook,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.58.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-UxselIcerU590C2hQP/ZsVo+vQf3y4L1AoW+oIBhEs8=";
  };

  vendorHash = "sha256-OL6QGf4xSMpEbmU+41pFdO0Rrs3H162T3pdiW9UfWR0=";

  nativeBuildInputs = [
    unpinGoModVersionHook
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
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "bd";
    platforms = platforms.unix;
  };
}
