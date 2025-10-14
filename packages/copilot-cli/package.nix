{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
}:

buildNpmPackage (finalAttrs: {
  pname = "copilot-cli";
  version = "0.0.340";

  src = fetchurl {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${finalAttrs.version}.tgz";
    hash = "sha256-YTpRZnmu4tHVb+H1wlrb496esm3+IrprLCDoQ2vR98w=";
  };

  npmDepsHash = "sha256-NoMyz4vjRjWHq42adT9Bjm16+znWQG7mq0qlSW9ToR0=";

  nodejs = nodejs_22;

  npmInstallFlags = [ "--omit=dev" ];

  dontNpmBuild = true;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${finalAttrs.pname}
    cp -r . $out/lib/${finalAttrs.pname}

    mkdir -p $out/bin
    makeWrapper ${nodejs_22}/bin/node $out/bin/copilot \
      --add-flags "$out/lib/${finalAttrs.pname}/index.js"

    runHook postInstall
  '';

  meta = {
    description = "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal.";
    homepage = "https://github.com/github/copilot-cli";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "copilot";
  };
})
