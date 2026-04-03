{
  lib,
  stdenv,
  fetchzip,
  fetchurl,
  fetchYarnDeps,
  runCommand,
  yarnConfigHook,
  yarnInstallHook,
  jq,
  nodejs,
  makeWrapper,
  versionCheckHook,
  versionCheckHomeHook,
  ripgrep,
  difftastic,
}:

let
  pin = lib.importJSON ./hashes.json;

  # Upstream merged the CLI into the slopus/happy yarn-workspaces monorepo
  # and stopped tagging it (the only tags, `v3` and `v1.1.0-2`, refer to the
  # mobile app). So track the npm release; the tarball already contains the
  # bundled dist/ output, leaving only runtime deps to install.
  #
  # The tarball ships no lockfile, but the monorepo root has the
  # authoritative yarn.lock. Pin to the commit that bumped package.json
  # to this version so the resolved deps match what was published.
  yarnLockUpstream = fetchurl {
    url = "https://raw.githubusercontent.com/slopus/happy/${pin.yarnLockCommit}/yarn.lock";
    hash = pin.yarnLockHash;
  };

  # @slopus/happy-wire is a workspace package in the monorepo (so no
  # lockfile entry) but is published to npm and listed as a regular dep
  # in the tarball's package.json. Append a stanza so yarn can resolve it.
  # The output is what both the FOD and the build's postPatch consume —
  # keeping it as a derivation avoids IFD on the fetchurl above.
  yarnLock =
    runCommand "happy-yarn.lock"
      {
        wireStanza = ''

          "@slopus/happy-wire@${pin.wireRange}":
            version "${pin.wireVersion}"
            resolved "${pin.wireResolved}"
            integrity ${pin.wireIntegrity}
            dependencies:
              "@paralleldrive/cuid2" "^2.2.2"
              zod "3.25.76"
        '';
        passAsFile = [ "wireStanza" ];
      }
      ''
        cat ${yarnLockUpstream} "$wireStanzaPath" > $out
      '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "happy-coder";
  inherit (pin) version;

  src = fetchzip {
    url = "https://registry.npmjs.org/happy/-/happy-${finalAttrs.version}.tgz";
    hash = pin.srcHash;
  };

  # `resolutions` only takes effect at the workspace root in yarn classic;
  # in the monorepo this block is dead, but here the tarball *is* the root,
  # so yarn suddenly tries to honour pins (e.g. whatwg-url@14.2.0) that the
  # upstream lockfile never resolved. Drop it to stay on the locked graph.
  postPatch = ''
    install -m 644 ${yarnLock} yarn.lock
    jq 'del(.resolutions)' package.json > package.json.new
    mv package.json.new package.json
  '';

  yarnOfflineCache = fetchYarnDeps {
    inherit yarnLock;
    hash = pin.yarnOfflineHash;
  };

  nativeBuildInputs = [
    jq
    nodejs
    yarnConfigHook
    yarnInstallHook
    makeWrapper
  ];

  # Upstream's postinstall (scripts/unpack-tools.cjs) extracts a 100 MB
  # multi-platform tarball collection (ripgrep / difftastic / a ripgrep
  # NAPI addon) into tools/unpacked/. The Mach-O / glibc binaries don't
  # work in the Nix sandbox anyway, so:
  #   - skip the script (yarnConfigHook already passes --ignore-scripts)
  #   - drop the archives to slim down the closure
  #   - symlink nixpkgs' ripgrep + difftastic so the hardcoded
  #     `tools/unpacked/{rg,difft}` lookups succeed
  #   - leave ripgrep.node missing — ripgrep_launcher.cjs falls back to
  #     the rg binary (and to PATH) when require() on the addon fails.
  postInstall = ''
    pkgDir=$out/lib/node_modules/happy

    rm -rf $pkgDir/tools/archives $pkgDir/tools/unpacked
    mkdir -p $pkgDir/tools/unpacked
    ln -s ${lib.getExe ripgrep} $pkgDir/tools/unpacked/rg
    ln -s ${lib.getExe difftastic} $pkgDir/tools/unpacked/difft

    for bin in happy happy-mcp; do
      wrapProgram $out/bin/$bin \
        --prefix PATH : ${
          lib.makeBinPath [
            nodejs
            ripgrep
            difftastic
          ]
        }
    done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = {
    description = "Mobile and Web client for Codex and Claude Code, with realtime voice and encryption";
    homepage = "https://github.com/slopus/happy";
    changelog = "https://github.com/slopus/happy/commits/main/packages/happy-cli";
    downloadPage = "https://www.npmjs.com/package/happy";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "happy";
    platforms = lib.platforms.all;
  };
})
