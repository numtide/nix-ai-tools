{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  runCommand,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
  
  # Fetch the source and patch go.mod to remove patch-level version constraints
  # This addresses the issue where dependencies require Go 1.25.5 but nixpkgs has 1.25.4
  # By relaxing the constraint to the minor version (1.25), the build can proceed
  patchedSrc = runCommand "crush-${version}-src" {} ''
    cp -r ${fetchFromGitHub {
      owner = "charmbracelet";
      repo = "crush";
      rev = "v${version}";
      inherit hash;
    }} $out
    chmod -R +w $out
    
    # Patch go.mod to relax patch-level version constraints
    # Converts "go X.Y.Z" to "go X.Y" to allow building with any patch version
    sed -i -E 's/^go ([0-9]+\.[0-9]+)\.[0-9]+$/go \1/' $out/go.mod
  '';
in
buildGoModule {
  pname = "crush";
  inherit version vendorHash;

  src = patchedSrc;

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
