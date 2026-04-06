{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  versionCheckHook,
}:

buildDotnetModule rec {
  pname = "officecli";
  version = "1.0.36";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "OfficeCLI";
    tag = "v${version}";
    hash = "sha256-sx1w3cSBiU7AUeW6k2nqAGOEZk+PrTZoyQnem9DK9j8=";
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
    maintainers = with maintainers; [ ];
    mainProgram = "officecli";
    platforms = platforms.unix;
  };
}
