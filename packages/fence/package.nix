{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  makeWrapper,
  go-bin,
  versionCheckHook,
  versionCheckHomeHook,
  # Linux dependencies
  bubblewrap,
  socat,
  bpftrace,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
in
(buildGoModule.override { go = go-bin; }) {
  pname = "fence";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "Use-Tusk";
    repo = "fence";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  subPackages = [ "cmd/fence" ];

  doCheck = false;

  doInstallCheck = true;

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${version}"
    "-X=main.buildTime=1970-01-01T00:00:00Z"
    "-X=main.gitCommit=v${version}"
  ];

  postInstall = ''
    installShellCompletion --cmd fence \
      --bash <($out/bin/fence completion bash) \
      --fish <($out/bin/fence completion fish) \
      --zsh <($out/bin/fence completion zsh)
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/fence \
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          socat
          bpftrace
        ]
      }
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Lightweight, container-free sandbox for running commands with network and filesystem restrictions";
    homepage = "https://fencesandbox.com/";
    changelog = "https://github.com/Use-Tusk/fence/releases";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "fence";
  };
}
