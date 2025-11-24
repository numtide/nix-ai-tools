{
  lib,
  stdenv,
  fetchzip,
  bun,
}:

stdenv.mkDerivation rec {
  pname = "ccusage";
  version = "17.1.6";

  src = fetchzip {
    url = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
    hash = "sha256-k2vhjvAlVCaDJKYcqdmJOjunHkGh7peWGiHH5iO4Dwo=";
  };

  nativeBuildInputs = [ bun ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp -r dist/* $out/bin/

    chmod +x $out/bin/index.js
    mv $out/bin/index.js $out/bin/ccusage

    substituteInPlace $out/bin/ccusage \
      --replace-quiet "#!/usr/bin/env node" "#!${bun}/bin/bun"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Usage analysis tool for Claude Code";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage";
    platforms = platforms.all;
  };
}
