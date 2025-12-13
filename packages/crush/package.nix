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
  
  # Generic solution for Go patch-level version mismatches:
  # When dependencies require a newer Go patch version than available in nixpkgs,
  # use GOTOOLCHAIN=auto in the FOD phase to download the required toolchain.
  # For the main build, use proxyVendor with GOTOOLCHAIN=auto to use the cached toolchain.
  proxyVendor = true;
  
  overrideModAttrs = oldAttrs: {
    env = (oldAttrs.env or { }) // {
      GOTOOLCHAIN = "auto";
    };
    preBuild = (oldAttrs.preBuild or "") + ''
      export GOTOOLCHAIN=auto
    '';
  };
  
  preBuild = ''
    export GOTOOLCHAIN=auto
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
