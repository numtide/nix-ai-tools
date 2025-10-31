{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  makeWrapper,
  darwinOpenptyHook,
}:

buildNpmPackage (finalAttrs: {
  pname = "claude-code-ui";
  version = "1.10.4";

  src = fetchFromGitHub {
    owner = "siteboon";
    repo = "claudecodeui";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Lzzgof2Pxbt0jWAV6b85qsXW/1dNzx8UDMjgH3xtpkI=";
  };

  npmDepsHash = "sha256-kivP2OlvT19GaLfTSl3Hxv+ve/B2UEVxSAS3c0c2T0s=";

  patches = [ ./use-state-dir-for-db.patch ];

  nativeBuildInputs =
    [
      python3
      makeWrapper
    ]
    ++ lib.optionals (stdenv.hostPlatform.isDarwin) [ darwinOpenptyHook ];

  meta = {
    description = "Web-based UI for Claude Code CLI";
    homepage = "https://claudecodeui.siteboon.ai";
    license = lib.licenses.unfree; # License not specified in package.json
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = lib.platforms.all;
    mainProgram = "claude-code-ui";
  };
})
