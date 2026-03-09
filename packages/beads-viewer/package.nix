{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads-viewer";
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "beads_viewer";
    rev = "v${version}";
    hash = "sha256-sdlw9Zr+/I1/PaX0Wpim+UGPxvP7hPrlJ0MTGC20Q5w=";
  };

  vendorHash = null;

  # Remove go version constraint that requires newer Go than nixpkgs provides
  postPatch = ''
    sed -i '/^toolchain /d' go.mod
  '';

  subPackages = [ "cmd/bv" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/Dicklesworthstone/beads_viewer/pkg/version.Version=v${version}"
  ];

  doCheck = false;

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Graph-aware TUI for the Beads issue tracker";
    homepage = "https://github.com/Dicklesworthstone/beads_viewer";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "bv";
    platforms = platforms.unix;
  };
}
