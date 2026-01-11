{
  lib,
  stdenv,
  fetchzip,
  bun,
  flake,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation rec {
  pname = "ccusage-codex";
  version = "18.0.5";

  src = fetchzip {
    url = "https://registry.npmjs.org/@ccusage/codex/-/codex-${version}.tgz";
    hash = "sha256-IZTYYNc2CGscQaIgSDderDZWKj6aTjCAKC/eA/AzOmY=";
  };

  nativeBuildInputs = [ bun ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp -r dist/* $out/bin/

    chmod +x $out/bin/index.js
    mv $out/bin/index.js $out/bin/ccusage-codex

    substituteInPlace $out/bin/ccusage-codex \
      --replace-fail "#!/usr/bin/env node" "#!${bun}/bin/bun"

    runHook postInstall
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Usage analysis tool for OpenAI Codex sessions";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ ryoppippi ];
    mainProgram = "ccusage-codex";
    platforms = platforms.all;
  };
}
