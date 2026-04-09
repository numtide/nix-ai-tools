{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go-bin,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildGoModule.override { go = go-bin; } rec {
  pname = "mardi-gras";
  version = "0.16.0";

  src = fetchFromGitHub {
    owner = "quietpublish";
    repo = "mardi-gras";
    rev = "v${version}";
    hash = "sha256-HVJ9Ed0xWOoUoQYKv5D1knUaYSlz8pkop7wdCLx8w4Q=";
  };

  vendorHash = "sha256-kE40FP5Asy0oxHgzNiWnPIik6mCUMKYBqist1zgBnMk=";

  subPackages = [ "cmd/mg" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Terminal UI for Beads issue tracking with a parade-inspired workflow view";
    homepage = "https://github.com/quietpublish/mardi-gras";
    changelog = "https://github.com/quietpublish/mardi-gras/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "mg";
    platforms = platforms.unix;
  };
}
