{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads-viewer";
  version = "0.14.4";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "beads_viewer";
    rev = "v${version}";
    hash = "sha256-0HK1ycgE9U57mYLhOgR68ElWQWXin4v5P7l1n4XECI8=";
  };

  vendorHash = null;

  subPackages = [ "cmd/bv" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/Dicklesworthstone/beads_viewer/pkg/version.version=v${version}"
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
    maintainers = with maintainers; [ afterthought ];
    mainProgram = "bv";
    platforms = platforms.unix;
  };
}
