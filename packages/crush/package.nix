{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  go_1_26,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
in
(buildGoModule.override { go = go_1_26; }) {
  pname = "crush";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [ installShellFiles ];

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  subPackages = [ "." ];

  # Tests require config files that aren't available in the build environment
  doCheck = false;

  doInstallCheck = true;

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  postInstall = ''
    installShellCompletion --cmd crush \
      --bash <($out/bin/crush completion bash) \
      --fish <($out/bin/crush completion fish) \
      --zsh <($out/bin/crush completion zsh)

    # Install JSON schema
    install -Dm644 schema.json $out/share/crush/schema.json
  '';

  passthru = {
    category = "AI Coding Agents";
    jsonschema = "${placeholder "out"}/share/crush/schema.json";
  };

  meta = with lib; {
    description = "The glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ zimbatm ];
    mainProgram = "crush";
  };
}
