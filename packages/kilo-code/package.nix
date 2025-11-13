{
  lib,
  buildNpmPackage,
  fetchzip,
  ripgrep,
  makeWrapper,
}:

buildNpmPackage (finalAttrs: {
  pname = "kilo-code";
  version = "0.2.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@kilocode/cli/-/cli-${finalAttrs.version}.tgz";
    hash = "sha256-uMAloANznWpnA2fMHH9gVnJTIS4mfT1quZ8J+aPWp6k=";
  };

  npmDepsHash = "sha256-1iwD6Ok45LR2QFjIBERcv32jhIejB2Te+zNZLshLYms=";

  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;

  # Make ripgrep available in PATH for the kilocode binary
  postInstall = ''
    wrapProgram $out/bin/kilocode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = {
    description = "The open-source AI coding agent. Now available in your terminal.";
    homepage = "https://kilocode.ai/cli";
    downloadPage = "https://www.npmjs.com/package/@kilocode/cli";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = lib.licenses.asl20;
    mainProgram = "kilocode";
    platforms = lib.platforms.all;
  };
})
