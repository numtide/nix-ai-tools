{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  runCommand,
  fetchzip,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
  
  # Pre-fetch and patch catwalk to remove Go version constraint
  # This is an FOD that vendors catwalk with a relaxed version requirement
  patchedCatwalk = runCommand "catwalk-v0.10.1-patched" {} ''
    cp -r ${fetchzip {
      url = "https://github.com/charmbracelet/catwalk/archive/refs/tags/v0.10.1.tar.gz";
      hash = "sha256-zcWKXojirBEoCUX8YS4JaCXyqn0jRD9uZsoLu//9358=";
    }} $out
    chmod -R +w $out
    
    # Patch catwalk's go.mod to relax version constraint
    sed -i -E 's/^go ([0-9]+\.[0-9]+)\.[0-9]+$/go \1/' $out/go.mod
  '';
  
  # Fetch the source and patch go.mod to remove patch-level version constraints
  # Also add a replace directive to use our patched catwalk
  patchedSrc = runCommand "crush-${version}-src" {} ''
    cp -r ${fetchFromGitHub {
      owner = "charmbracelet";
      repo = "crush";
      rev = "v${version}";
      inherit hash;
    }} $out
    chmod -R +w $out
    
    # Patch go.mod to relax patch-level version constraints
    sed -i -E 's/^go ([0-9]+\.[0-9]+)\.[0-9]+$/go \1/' $out/go.mod
    
    # Add replace directive to use our patched catwalk
    echo "" >> $out/go.mod
    echo "replace github.com/charmbracelet/catwalk => ${patchedCatwalk}" >> $out/go.mod
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
