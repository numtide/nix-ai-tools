{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  flake,
}:

stdenv.mkDerivation rec {
  pname = "claude-plugins";
  version = "0.2.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-brHWAykKlGW6nJ/28cE0g8zx8lzcuNH893kuyceDp/4=";
  };

  nativeBuildInputs = [ nodejs ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src/dist/index.js $out/bin/claude-plugins
    chmod +x $out/bin/claude-plugins

    substituteInPlace $out/bin/claude-plugins \
      --replace-quiet "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    runHook postInstall
  '';

  passthru.category = "Claude Code Ecosystem";

  meta = with lib; {
    description = "CLI tool for managing Claude Code plugins";
    homepage = "https://github.com/Kamalnrf/claude-plugins";
    changelog = "https://github.com/Kamalnrf/claude-plugins/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ ypares ];
    mainProgram = "claude-plugins";
    platforms = platforms.all;
  };
}
