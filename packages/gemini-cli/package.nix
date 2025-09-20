{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_20,
  runCommand,
  stdenv,
}:

let
  version = "0.5.5";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "gemini-cli-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-${version}.tgz";
        hash = "sha256-nVW1FEDplwlmFuTJ4pVmXtyQBYPxx2KhIv+4cudZwG0=";
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage rec {
  pname = "gemini-cli";
  inherit version;

  src = srcWithLock;

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-QU+wyCMfhMjlBv2II3GC0RvAzQci7ZzGiQfXncDF6xY=";
  };

  # The package from npm is already built
  dontNpmBuild = true;

  # On aarch64-darwin, avoid running install scripts that try to build
  # optional native deps (node-pty) with node-gyp and fail.
  npmFlags = lib.optionals (stdenv.isAarch64 && stdenv.isDarwin) [ "--ignore-scripts" ];

  nodejs = nodejs_20;

  passthru = {
    updateScript = ./update.sh;
  };

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    changelog = "https://github.com/google-gemini/gemini-cli/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ donteatoreo ];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
}
