{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
in
buildGoModule {
  pname = "crush";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [ installShellFiles ];

  # Patch go.mod to remove tight patch-level version constraint
  # Converts "go X.Y.Z" to "go X.Y" to allow building with any patch version
  preBuild = ''
    sed -i -E 's/^go ([0-9]+\.[0-9]+)\.[0-9]+$/go \1/' go.mod
  '';

  # Tests require config files that aren't available in the build environment
  doCheck = false;

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
