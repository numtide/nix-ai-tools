{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.30.2";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-ltzLDSkW1Qtxqy6LwLKPn20o6LzWEJ0Nvp9wP3VKp8Q=";
  };

  vendorHash = "sha256-ha3sFcbr3fGrHVtSnbrDut/DAnCEy3uGtrcQAozAFJs=";

  subPackages = [ "cmd/bd" ];

  doCheck = false;

  meta = with lib; {
    description = "A distributed issue tracker designed for AI-supervised coding workflows";
    homepage = "https://github.com/steveyegge/beads";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "bd";
    platforms = platforms.unix;
  };
}
