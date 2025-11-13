{
  lib,
  buildNpmPackage,
  fetchzip,
  ripgrep,
}:

buildNpmPackage (finalAttrs: {
  pname = "kilo-code";
  version = "0.2.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@kilocode/cli/-/cli-${finalAttrs.version}.tgz";
    hash = "sha256-uMAloANznWpnA2fMHH9gVnJTIS4mfT1quZ8J+aPWp6k=";
  };

  npmDepsHash = "sha256-1iwD6Ok45LR2QFjIBERcv32jhIejB2Te+zNZLshLYms=";

  buildInputs = [ ripgrep ];

  # Disable the problematic postinstall script
  npmFlags = [ "--ignore-scripts" ];

  # After npm install, we need to handle the ripgrep dependency
  postInstall = ''
    # Make ripgrep available by creating a symlink or setting environment variable
    mkdir -p node_modules/@vscode/ripgrep/bin
    ln -s ${ripgrep}/bin/rg node_modules/@vscode/ripgrep/bin/rg

    # Run the postinstall script manually if needed
    if [ -f node_modules/@vscode/ripgrep/lib/postinstall.js ]; then
      HOME=$TMPDIR node node_modules/@vscode/ripgrep/lib/postinstall.js || true
    fi
  '';

  dontNpmBuild = true;

  doInstallCheck = true;
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

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
