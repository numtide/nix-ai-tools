{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  flake,
}:

stdenv.mkDerivation rec {
  pname = "skills-installer";
  version = "0.2.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-UWddwsNoULVCOVeXHr+WEeWnouc4/AplqYfBWd0oTRg=";
  };

  nativeBuildInputs = [ nodejs ];

  installPhase = ''
    runHook preInstall

    install -Dm755 dist/cli.js $out/bin/skills-installer

    substituteInPlace $out/bin/skills-installer \
      --replace-fail "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/skills-installer --help > /dev/null
    runHook postInstallCheck
  '';

  passthru.category = "Claude Code Ecosystem";

  meta = with lib; {
    description = "Install agent skills across multiple AI coding clients";
    homepage = "https://github.com/Kamalnrf/claude-plugins";
    changelog = "https://github.com/Kamalnrf/claude-plugins/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ Bad3r ];
    mainProgram = "skills-installer";
    platforms = platforms.all;
  };
}
