{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.46.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-PMzLKb0pYKiXdiEXBFe6N4FZ3AaNfvBRZlQBKijtldc=";
  };

  vendorHash = "sha256-BpACCjVk0V5oQ5YyZRv9wC/RfHw4iikc2yrejZzD1YU=";

  subPackages = [ "cmd/bd" ];

  doCheck = false;

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

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
