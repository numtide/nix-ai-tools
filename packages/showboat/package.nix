{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "showboat";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "simonw";
    repo = "showboat";
    rev = "v${version}";
    hash = "sha256-yYK6j6j7OgLABHLOSKlzNnm2AWzM2Ig76RJypBsBnkI=";
  };

  vendorHash = "sha256-mGKxBRU5TPgdmiSx0DHEd0Ys8gsVD/YdBfbDdSVpC3U=";

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${version}"
  ];

  # Tests require python3 and other executors in PATH
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Create executable demo documents showing and proving an agent's work";
    homepage = "https://github.com/simonw/showboat";
    changelog = "https://github.com/simonw/showboat/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ jfroche ];
    mainProgram = "showboat";
    platforms = platforms.unix;
  };
}
