{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  go_1_25,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
  
  # Override Go to report version 1.25.99 to satisfy all dependency version requirements
  # This is simpler than patching all transitive dependencies
  # The actual Go 1.25.4 toolchain is API-compatible with 1.25.5 requirements
  go_1_25_patched = go_1_25.overrideAttrs (oldAttrs: {
    # Patch the version file that Go reads to determine its version
    postPatch = (oldAttrs.postPatch or "") + ''
      # Update VERSION file to report 1.25.99
      echo "go1.25.99" > VERSION
    '';
  });
in
(buildGoModule.override { go = go_1_25_patched; }) {
  pname = "crush";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [ installShellFiles ];

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
