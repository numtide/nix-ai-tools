{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  pkg-config,
  nodejs,
  pnpm,
  versionCheckHook,
  versionCheckHomeHook,
  npmConfigHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;
in
buildNpmPackage {
  inherit
    npmConfigHook
    nodejs
    version
    npmDepsHash
    ;

  pname = "kiri";

  src = fetchFromGitHub {
    owner = "CAPHTECH";
    repo = "kiri";
    tag = "v${version}";
    inherit hash;
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    # Remove packageManager field to use system pnpm instead of self-installing
    ${nodejs}/bin/node -e "
      const pkg = require('./package.json');
      delete pkg.packageManager;
      require('fs').writeFileSync('./package.json', JSON.stringify(pkg, null, 2) + '\n');
    "
  '';

  nativeBuildInputs = [
    pnpm
    pkg-config
  ];

  npmFlags = [ "--legacy-peer-deps" ];
  # tree-sitter-cli tries to download prebuilt binary during postinstall
  npmRebuildFlags = [ "--ignore-scripts" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = {
    description = "Intelligent code context extraction for LLMs via Model Context Protocol";
    homepage = "https://github.com/CAPHTECH/kiri";
    changelog = "https://github.com/CAPHTECH/kiri/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "kiri";
    platforms = lib.platforms.all;
  };
}
