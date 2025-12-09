{
  lib,
  stdenv,
  fetchzip,
  bun,
  flake,
}:

stdenv.mkDerivation rec {
  pname = "ccusage";
  version = "17.1.8";

  src = fetchzip {
    url = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
    hash = "sha256-p7pGN7x5q7SoXxO3ySMuqf7WI+wrQogyw1t8e5LS1Qk=";
  };

  nativeBuildInputs = [ bun ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp -r dist/* $out/bin/

    chmod +x $out/bin/index.js
    mv $out/bin/index.js $out/bin/ccusage

    substituteInPlace $out/bin/ccusage \
      --replace-fail "#!/usr/bin/env node" "#!${bun}/bin/bun"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Usage analysis tool for Claude Code";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ ryoppippi ];
    mainProgram = "ccusage";
    platforms = platforms.all;
  };
}
