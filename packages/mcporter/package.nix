{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  makeWrapper,
  nodejs,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mcporter";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "mcporter";
    rev = "v${finalAttrs.version}";
    hash = "sha256-IH0jYDkmEPPvy/g5+YfkNBwG2QUMwkuVCnSeSTsNHNw=";
  };

  # Upstream's lockfile was generated before the pnpm.overrides entry for vite
  # was applied, so newer pnpm rejects it as out of sync with package.json.
  # https://github.com/steipete/mcporter/issues/new (lockfile drift)
  postPatch = ''
    sed -i 's/specifier: \^8\.0\.8/specifier: 8.0.8/' pnpm-lock.yaml
  '';

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    hash = "sha256-dCue5Id5gcddoqoHKeB3uwxR4jtoBJx/mUzHLnb8o14=";
    fetcherVersion = 2;
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/mcporter}

    # Prune dev dependencies to reduce closure size
    pnpm prune --prod

    cp -r dist $out/lib/mcporter/
    cp -r node_modules $out/lib/mcporter/
    cp package.json $out/lib/mcporter/

    makeWrapper ${nodejs}/bin/node $out/bin/mcporter \
      --add-flags "$out/lib/mcporter/dist/cli.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = {
    description = "TypeScript runtime and CLI for the Model Context Protocol";
    homepage = "https://github.com/steipete/mcporter";
    changelog = "https://github.com/steipete/mcporter/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "mcporter";
  };
})
