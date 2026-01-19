{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  ripgrep,
  pkg-config,
  libsecret,
  darwinOpenptyHook,
  clang_20,
  makeBinaryWrapper,
  versionCheckHook,
  xsel,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "gemini-cli";
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PqftnXy7pOY7teBHXzVH1mMECnximQwyYvgxqPH/Ulw=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-hilLONJfva4UP+8pfEnrxypjb8FrYSuiQz0Q1E6S/Ug=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  nativeBuildInputs = [
    pkg-config
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    clang_20 # Works around node-addon-api constant expression issue with clang 21+
    darwinOpenptyHook # Fixes node-pty openpty/forkpty build issue
  ];

  buildInputs = [
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
    cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
    cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server

    # Remove dangling symlinks to source directory
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    ln -s $out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js $out/bin/gemini
    chmod +x "$out/bin/gemini"

    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      wrapProgram $out/bin/gemini \
        --prefix PATH : ${
          lib.makeBinPath [
            xsel
            ripgrep
          ]
        }
    ''}

    # Install JSON schema
    install -Dm644 schemas/settings.schema.json $out/share/gemini-cli/settings.schema.json

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    category = "AI Coding Agents";
    jsonschema = "${placeholder "out"}/share/gemini-cli/settings.schema.json";
  };

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
})
