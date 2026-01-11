{
  lib,
  stdenv,
  buildNpmPackage,
  fetchzip,
  makeWrapper,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  runCommand,
  # Linux dependencies
  bubblewrap,
  socat,
  ripgrep,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;

  # Create a source with the vendored package-lock.json included
  src = runCommand "sandbox-runtime-src-with-lock" { } ''
    mkdir -p $out
    cp -r ${
      fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/sandbox-runtime/-/sandbox-runtime-${version}.tgz";
        inherit hash;
      }
    }/* $out/
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit npmConfigHook nodejs;
  pname = "sandbox-runtime";
  inherit version src;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "sandbox-runtime-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    # On Linux, wrap the binary to add bubblewrap to PATH, but put it at the end
    # so the system bubblewrap is preferred (Ubuntu ships special apparmor policies)
    # Also add socat and ripgrep which are required dependencies
    wrapProgram $out/bin/srt \
      --suffix PATH : ${
        lib.makeBinPath [
          bubblewrap
          socat
          ripgrep
        ]
      }
  '';

  # Version check disabled - the tool reports a different version than the package version
  # (1.0.0 from commander instead of 0.0.26 from package.json)
  doInstallCheck = false;

  passthru.category = "Claude Code Ecosystem";

  meta = {
    description = "Lightweight sandboxing tool for enforcing filesystem and network restrictions";
    longDescription = ''
      Anthropic Sandbox Runtime (srt) is a lightweight sandboxing tool for
      enforcing filesystem and network restrictions on arbitrary processes at
      the OS level, without requiring a container.

      It uses native OS sandboxing primitives (sandbox-exec on macOS,
      bubblewrap on Linux) and proxy-based network filtering. It can be used
      to sandbox the behaviour of agents, local MCP servers, bash commands
      and arbitrary processes.
    '';
    homepage = "https://github.com/anthropic-experimental/sandbox-runtime";
    changelog = "https://github.com/anthropic-experimental/sandbox-runtime/releases";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "srt";
    platforms = lib.platforms.unix;
  };
}
