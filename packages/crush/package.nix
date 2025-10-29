{
  lib,
  buildGo125Module,
  fetchFromGitHub,
}:
buildGo125Module rec {
  pname = "crush";
  version = "0.13.3";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-oS5bfz7+Vt/26sY0m5jZS8msE1pFRs37RlOqFyurPXI=";
  };

  vendorHash = "sha256-OiNmZKg+NN7Aoeao8L72Dvgz0moeaZGQ7KVJdvuWagY=";

  # Tests require config files that aren't available in the build environment
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  meta = with lib; {
    description = "The glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ zimbatm ];
    mainProgram = "crush";
  };
}
