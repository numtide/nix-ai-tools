{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs_22,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;

  # Create a source with package-lock.json included
  srcWithLock = runCommand "clawdbot-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/clawdbot/-/clawdbot-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit npmConfigHook version;
  pname = "clawdbot";
  nodejs = nodejs_22;

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    src = srcWithLock;
    name = "clawdbot-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    cacheVersion = 2;
  };
  makeCacheWritable = true;

  # The package from npm is already built
  dontNpmBuild = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = {
    description = "Personal AI assistant with WhatsApp, Telegram, Discord integration";
    homepage = "https://clawd.bot";
    changelog = "https://github.com/clawdbot/clawdbot/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
    mainProgram = "clawdbot";
  };
}
