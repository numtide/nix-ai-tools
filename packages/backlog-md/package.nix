{
  lib,
  stdenv,
  bun2nix,
  bun,
  fetchFromGitHub,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation {
  pname = "backlog-md";
  inherit version;

  src = fetchFromGitHub {
    owner = "MrLesk";
    repo = "Backlog.md";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nix.hook
    bun
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # We handle build and install ourselves since we need a custom
  # two-step build: CSS compilation then bun build --compile
  dontUseBunBuild = true;
  dontUseBunInstall = true;

  # postinstall runs bun2nix (needs .git), prepare runs husky (needs .git)
  dontRunLifecycleScripts = true;

  buildPhase = ''
    runHook preBuild

    # Native node modules like @parcel/watcher need libstdc++ at build time
    ${lib.optionalString stdenv.isLinux ''
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
    ''}

    # Step 1: Build CSS with tailwindcss
    bun ./node_modules/@tailwindcss/cli/dist/index.mjs \
      -i src/web/styles/source.css \
      -o src/web/styles/style.css \
      --minify

    # Step 2: Compile standalone binary
    bun build --production --compile --minify \
      --outfile=dist/backlog src/cli.ts

    runHook postBuild
  '';

  # bun compile embeds JS in the binary; stripping would break it
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp dist/backlog $out/bin/backlog

    runHook postInstall
  '';

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem";
    homepage = "https://github.com/MrLesk/Backlog.md";
    changelog = "https://github.com/MrLesk/Backlog.md/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "backlog";
    platforms = platforms.unix;
  };
}
