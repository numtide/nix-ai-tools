{
  buildNpmPackage,
  fetchzip,
  lib,
  ripgrep,
  versionCheckHook,
}:
buildNpmPackage (finalAttrs: {
  pname = "kilocode-cli";
  version = "0.12.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@kilocode/cli/-/cli-${finalAttrs.version}.tgz";
    hash = "sha256-bma5ipS5vUMm+cu2TUQOnPrryXkqnp7/WBwdHHRTvWk=";
  };

  npmDepsHash = "sha256-5uyvG4/PsSHn6Bh4bfI2J7vceujI8ybjD5hzBzH3giY=";

  buildInputs = [
    ripgrep
  ];

  postPatch = ''
    # npm-shrinkwrap.json is functionally equivalent to package-lock.json
    ln -s npm-shrinkwrap.json package-lock.json
  '';

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

    # Install JSON schema
    install -Dm644 config/schema.json $out/share/kilocode-cli/schema.json
  '';

  passthru = {
    jsonschema = "${placeholder "out"}/share/kilocode-cli/schema.json";
  };

  dontNpmBuild = true;

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  doCheck = false; # there are no unit tests in the package release

  meta = {
    description = "The open-source AI coding agent. Now available in your terminal.";
    homepage = "https://kilocode.ai/cli";
    downloadPage = "https://www.npmjs.com/package/@kilocode/cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "kilocode";
  };
})
