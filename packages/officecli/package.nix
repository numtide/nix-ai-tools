{
  lib,
  flake,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  versionCheckHook,
}:

buildDotnetModule rec {
  pname = "officecli";
  version = "1.0.148";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "OfficeCLI";
    tag = "v${version}";
    hash = "sha256-AgiufIxzzjZfZ5lKk+l5e3Tz2vrxmv1ysV1dIQsCI1U=";
  };

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  selfContainedBuild = true;
  projectFile = "src/officecli/officecli.csproj";
  executables = [ "officecli" ];
  nugetDeps = ./deps.json;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "CLI for creating and editing Office Open XML documents";
    homepage = "https://github.com/iOfficeAI/OfficeCLI";
    changelog = "https://github.com/iOfficeAI/OfficeCLI/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "officecli";
    platforms = platforms.unix;
  };
}
