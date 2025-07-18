{ pkgs, perSystem }:
let
  # Bundle all the tools Claude needs into a single environment
  claudeTools = pkgs.buildEnv {
    name = "claude-tools";
    paths = with pkgs; [
      # Essential tools Claude commonly uses
      git
      ripgrep
      fd
      coreutils
      gnugrep
      gnused
      gawk
      findutils
      which
      tree
      curl
      wget
      jq
      less
      # Shells
      zsh
      # Nix is essential for nix run
      nix
    ];
  };
in
pkgs.runCommand "claudebox"
  {
    buildInputs = [ pkgs.makeWrapper ];
  }
  ''
    mkdir -p $out/bin $out/share/claudebox $out/libexec/claudebox

    # Install helper scripts
    cp ${./claudebox.sh} $out/bin/claudebox
    chmod +x $out/bin/claudebox

    # Install command-viewer script
    cp ${./command-viewer.js} $out/libexec/claudebox/command-viewer.js

    # Create wrapper for command-viewer
    makeWrapper ${pkgs.nodejs}/bin/node $out/libexec/claudebox/command-viewer \
      --add-flags $out/libexec/claudebox/command-viewer.js

    # Patch shebang
    patchShebangs $out/bin/claudebox

    # Create claude wrapper that references the original
    makeWrapper ${perSystem.self.claude-code}/bin/claude $out/libexec/claudebox/claude \
      --unset DEV \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_TELEMETRY 1 \
      --set NODE_OPTIONS "--require=${./command-logger.js}" \
      --inherit-argv0

    # Wrap claudebox start script
    wrapProgram $out/bin/claudebox \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.bashInteractive
          pkgs.bubblewrap
          pkgs.tmux
          claudeTools
        ]
      } \
      --prefix PATH : $out/libexec/claudebox
  ''
