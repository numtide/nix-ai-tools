{
  lib,
  flake,
  buildNpmPackage,
  nodejs,
  jq,
  runCommand,
  makeWrapper,
  versionCheckHook,
  versionCheckHomeHook,
  upstream,
  gooseServer,
}:

let
  srcWithPatchedPackage = runCommand "goose-cli-src" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${upstream.cliNpmSrc} -C $out --strip-components=1
    chmod -R u+w $out
    cp ${./package-lock.json} $out/package-lock.json
    jq 'del(.optionalDependencies) | .scripts.postinstall = ""' \
      $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
  '';
in
buildNpmPackage (_finalAttrs: {
  pname = "goose-cli";
  version = upstream.cliVersion;

  src = srcWithPatchedPackage;
  npmDepsHash = "sha256-BcKEuVR3oPURBMce30CyhR1dQwncu1Wi/vMhhSNl2R4=";

  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev

    mkdir -p $out/lib/goose-cli $out/bin
    cp -r dist package.json README.md node_modules $out/lib/goose-cli/

    makeWrapper ${nodejs}/bin/node $out/bin/goose \
      --add-flags $out/lib/goose-cli/dist/tui.js \
      --prefix PATH : ${lib.makeBinPath [ gooseServer ]} \
      --set GOOSE_BINARY ${gooseServer}/bin/goose

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "TypeScript terminal UI for Goose, backed by shared Goose binaries";
    homepage = "https://github.com/aaif-goose/goose";
    changelog = "https://github.com/aaif-goose/goose/releases/tag/v${upstream.desktopVersion}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "goose";
    platforms = [ "x86_64-linux" ];
  };
})
