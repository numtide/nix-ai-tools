{
  lib,
  buildGoModule,
  go_1_26,
  fetchFromGitHub,
  unpinGoModVersionHook,
  versionCheckHook,
  flake,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
in
buildGoModule.override { go = go_1_26; } {
  pname = "cli-proxy-api-plus";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPIPlus";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [ unpinGoModVersionHook ];

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=nixpkgs"
    "-X main.BuildDate=1970-01-01T00:00:00Z"
  ];

  postInstall = ''
    mv $out/bin/server $out/bin/cli-proxy-api-plus
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Unified proxy providing OpenAI/Gemini/Claude/Codex and others compatible APIs for AI coding CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPIPlus";
    changelog = "https://github.com/router-for-me/CLIProxyAPIPlus/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ odysseus0 ];
    mainProgram = "cli-proxy-api-plus";
    platforms = platforms.all;
  };
}
