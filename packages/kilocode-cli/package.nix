{
  buildNpmPackage,
  fetchzip,
  lib,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  ripgrep,
  versionCheckHook,
}:
buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "kilocode-cli";
  version = "0.22.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@kilocode/cli/-/cli-${finalAttrs.version}.tgz";
    hash = "sha256-WshsgU2CvhgwRSfHbhUm4hhJeTa5NbTz6CPM2QZeTTQ=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-djr2sOSVNwNSfqRBw0D2jFE/fmNLN6iv547/4aY714g=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

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
    category = "AI Coding Agents";
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
