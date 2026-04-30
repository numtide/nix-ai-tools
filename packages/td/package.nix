{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "td";
  version = "0.44.0";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "td";
    rev = "v${version}";
    hash = "sha256-k1OCK6LE99fHLuxv8HZUW8cSn2Wmk74J7kb6Mi5ZpVw=";
  };

  vendorHash = "sha256-hFFG+vLXcL2NNdLQvQZ1hzu++pp5AkbFOPQS10wtsec=";

  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${version}"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "A minimalist CLI for tracking tasks across AI coding sessions.";
    homepage = "https://github.com/marcus/td";
    changelog = "https://github.com/marcus/td/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "td";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
