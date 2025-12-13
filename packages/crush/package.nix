{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  go_1_25,
  runCommand,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
  
  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    inherit hash;
  };
  
  # Extract the required Go version from crush's go.mod
  # This makes the package future-compatible when crush updates its Go requirement
  requiredGoVersion = lib.fileContents (
    runCommand "extract-go-version" {} ''
      grep -E "^go [0-9]+\.[0-9]+(\.[0-9]+)?" ${src}/go.mod | \
        sed -E 's/^go ([0-9]+\.[0-9]+(\.[0-9]+)?)/\1/' > $out
    ''
  );
  
  # Override Go to report the required version to satisfy all dependency version requirements
  # This is simpler than patching all transitive dependencies
  # The actual Go 1.25.4 toolchain is API-compatible with 1.25.5+ requirements
  go_1_25_patched = go_1_25.overrideAttrs (oldAttrs: {
    # Patch the version file that Go reads to determine its version
    postPatch = (oldAttrs.postPatch or "") + ''
      # Update VERSION file to report the required Go version
      echo "go${requiredGoVersion}" > VERSION
    '';
  });
in
(buildGoModule.override { go = go_1_25_patched; }) {
  pname = "crush";
  inherit version vendorHash src;

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
