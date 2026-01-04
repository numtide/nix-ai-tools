# Custom fetchNpmDeps with packument caching support (fetcherVersion = 2)
# This builds a vendored prefetch-npm-deps with packument fetching support,
# which is needed for npm workspace support.
# TODO: Remove this once the upstream PR is merged into nixpkgs.
#
# Pin to nodejs_24 to ensure consistent npmDepsHash across nixpkgs versions.
# See: https://github.com/numtide/llm-agents.nix/issues/1644
{
  lib,
  stdenv,
  stdenvNoCC,
  rustPlatform,
  makeSetupHook,
  makeWrapper,
  pkg-config,
  curl,
  gnutar,
  gzip,
  cacert,
  config,
  nodejs_24,
  srcOnly,
  diffutils,
  jq,
}:
let
  nodejs = nodejs_24;

  # Build prefetch-npm-deps from vendored source with packument support
  prefetch-npm-deps = rustPlatform.buildRustPackage {
    pname = "prefetch-npm-deps";
    version = "0.1.0-packument";

    src = ./prefetch-npm-deps;

    cargoLock.lockFile = ./prefetch-npm-deps/Cargo.lock;

    nativeBuildInputs = [
      makeWrapper
      pkg-config
    ];
    buildInputs = [ curl ];

    postInstall = ''
      wrapProgram "$out/bin/prefetch-npm-deps" --prefix PATH : ${
        lib.makeBinPath [
          gnutar
          gzip
        ]
      }
    '';

    meta = {
      description = "Prefetch dependencies from npm with packument support";
      mainProgram = "prefetch-npm-deps";
      license = lib.licenses.mit;
    };
  };

  # Custom npmConfigHook that uses our patched prefetch-npm-deps
  npmConfigHook = makeSetupHook {
    name = "npm-config-hook-packument";
    substitutions = {
      nodeSrc = srcOnly nodejs;
      nodeGyp = "${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js";
      npmArch = stdenv.targetPlatform.node.arch;
      npmPlatform = stdenv.targetPlatform.node.platform;
      diff = "${diffutils}/bin/diff";
      jq = "${jq}/bin/jq";
      prefetchNpmDeps = "${prefetch-npm-deps}/bin/prefetch-npm-deps";
      nodeVersion = nodejs.version;
      nodeVersionMajor = lib.versions.major nodejs.version;
    };
  } ./npm-config-hook.sh;

  fetchNpmDepsWithPackuments =
    {
      name ? "npm-deps",
      hash ? "",
      forceGitDeps ? false,
      forceEmptyCache ? false,
      nativeBuildInputs ? [ ],
      npmRegistryOverridesString ? config.npmRegistryOverridesString or "{}",
      # Fetcher format version. Set to 2 to enable packument caching for workspace support.
      fetcherVersion ? 1,
      ...
    }@args:
    let
      hash_ =
        if hash != "" then
          { outputHash = hash; }
        else
          {
            outputHash = "";
            outputHashAlgo = "sha256";
          };

      forceGitDeps_ = lib.optionalAttrs forceGitDeps { FORCE_GIT_DEPS = true; };
      forceEmptyCache_ = lib.optionalAttrs forceEmptyCache { FORCE_EMPTY_CACHE = true; };
    in
    stdenvNoCC.mkDerivation (
      args
      // {
        inherit name;

        nativeBuildInputs = nativeBuildInputs ++ [ prefetch-npm-deps ];

        buildPhase = ''
          runHook preBuild

          if [[ -f npm-shrinkwrap.json ]]; then
            local -r srcLockfile="npm-shrinkwrap.json"
          elif [[ -f package-lock.json ]]; then
            local -r srcLockfile="package-lock.json"
          else
            echo
            echo "ERROR: No lock file!"
            echo
            echo "package-lock.json or npm-shrinkwrap.json is required to make sure"
            echo "that npmDepsHash doesn't change when packages are updated on npm."
            echo
            echo "Hint: You can copy a vendored package-lock.json file via postPatch."
            echo

            exit 1
          fi

          prefetch-npm-deps $srcLockfile $out

          runHook postBuild
        '';

        dontInstall = true;

        impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [ "NIX_NPM_TOKENS" ];

        NIX_NPM_REGISTRY_OVERRIDES = npmRegistryOverridesString;

        # Fetcher version controls which features are enabled in prefetch-npm-deps
        # Version 2+ enables packument fetching for workspace support
        NPM_FETCHER_VERSION = toString fetcherVersion;

        SSL_CERT_FILE =
          if
            (
              hash_.outputHash == ""
              || hash_.outputHash == lib.fakeSha256
              || hash_.outputHash == lib.fakeSha512
              || hash_.outputHash == lib.fakeHash
            )
          then
            "${cacert}/etc/ssl/certs/ca-bundle.crt"
          else
            "/no-cert-file.crt";

        outputHashMode = "recursive";
      }
      // hash_
      // forceGitDeps_
      // forceEmptyCache_
    );
in
{
  inherit fetchNpmDepsWithPackuments npmConfigHook prefetch-npm-deps;
}
