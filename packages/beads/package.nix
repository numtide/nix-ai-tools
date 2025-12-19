{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.30.6";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-ImxTgBy/aMPsL9O+/VDq86me66LWhM1FZaAHW3WaJwM=";
  };

  vendorHash = "sha256-Gyj/Vs3IEWPwqzfNoNBSL4VFifEhjnltlr1AROwGPc4=";

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
