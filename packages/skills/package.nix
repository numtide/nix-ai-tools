{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  nodejs,
  flake,
}:

let
  yaml = fetchzip {
    url = "https://registry.npmjs.org/yaml/-/yaml-2.8.3.tgz";
    hash = "sha256-sslihpXhi8dVxXJ8svHg4lpKGdGL74Oqqs5J/P/jvDg=";
  };
in
stdenv.mkDerivation rec {
  pname = "skills";
  version = "1.5.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-FWmQof42nLo8+w3UQBaalcJ4sAMRoZqeFnvuSe5yroI=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ nodejs ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/skills/node_modules/yaml
    cp -r ${yaml}/* $out/libexec/skills/node_modules/yaml/

    cp -r bin dist package.json $out/libexec/skills/

    mkdir -p $out/bin
    makeWrapper $out/libexec/skills/bin/cli.mjs $out/bin/skills \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set DISABLE_TELEMETRY 1

    ln -s $out/bin/skills $out/bin/add-skill

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ nodejs ];
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/skills --help 2>&1 | grep -qi "skill"
    runHook postInstallCheck
  '';

  passthru.category = "Claude Code Ecosystem";

  meta = with lib; {
    description = "The open agent skills tool for installing and managing skills across AI coding agents";
    homepage = "https://github.com/vercel-labs/skills";
    changelog = "https://github.com/vercel-labs/skills/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ ];
    mainProgram = "skills";
    platforms = platforms.all;
  };
}
