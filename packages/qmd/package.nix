{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeWrapper,
  sqlite,
}:
let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) rev srcHash bunDepsHash;

  version = "1.0.0-unstable";

  src = fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    inherit rev;
    hash = srcHash;
  };

  bunDeps = stdenv.mkDerivation {
    pname = "qmd-bun-deps";
    inherit version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [ bun ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      export HOME=$(mktemp -d)
      bun install --no-progress --frozen-lockfile

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -R node_modules $out/

      runHook postInstall
    '';

    outputHash =
      bunDepsHash.${stdenv.hostPlatform.system}
        or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };
in
stdenv.mkDerivation {
  pname = "qmd";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ sqlite ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/qmd $out/bin

    cp -r ${bunDeps}/node_modules $out/lib/qmd/
    cp -r src $out/lib/qmd/
    cp package.json $out/lib/qmd/

    makeWrapper ${bun}/bin/bun $out/bin/qmd \
      --add-flags "$out/lib/qmd/src/qmd.ts" \
      --set DYLD_LIBRARY_PATH "${sqlite.out}/lib" \
      --set LD_LIBRARY_PATH "${sqlite.out}/lib"

    runHook postInstall
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "mini cli search engine for your docs, knowledge bases, meeting notes, whatever. Tracking current sota approaches while being all local";
    homepage = "https://github.com/tobi/qmd";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    mainProgram = "qmd";
  };
}
