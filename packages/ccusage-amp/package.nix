{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation rec {
  pname = "ccusage-amp";
  version = "18.0.10";

  src = fetchzip {
    url = "https://registry.npmjs.org/@ccusage/amp/-/amp-${version}.tgz";
    hash = "sha256-efahFS9R9p3HTkONoI47YnawQc8lZSGMEdrPK8+UqDQ=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp -r dist/* $out/bin/

    chmod +x $out/bin/index.js
    mv $out/bin/index.js $out/bin/ccusage-amp

    substituteInPlace $out/bin/ccusage-amp \
      --replace-fail "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    runHook postInstall
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Usage analysis tool for Amp CLI sessions";
    homepage = "https://github.com/ryoppippi/ccusage";
    changelog = "https://github.com/ryoppippi/ccusage/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage-amp";
    platforms = platforms.all;
  };
}
