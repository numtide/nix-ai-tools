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
    meta = with pkgs.lib; {
      mainProgram = "claudebox";
      description = "Sandboxed environment for Claude Code";
      homepage = "https://github.com/numtide/llm-agents.nix/tree/main/packages/claudebox";
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.linux;
    };
  }
  ''
    mkdir -p $out/bin $out/share/claudebox $out/libexec/claudebox

    # Install claudebox launcher script
    cp ${./claudebox.js} $out/libexec/claudebox/claudebox.js

    # Install command-viewer script
    cp ${./command-viewer.js} $out/libexec/claudebox/command-viewer.js

    # Install wrapper script
    cp ${./command-viewer-wrapper.sh} $out/libexec/claudebox/command-viewer-wrapper.sh
    chmod +x $out/libexec/claudebox/command-viewer-wrapper.sh

    # Create the real command-viewer executable
    makeWrapper ${pkgs.nodejs}/bin/node $out/libexec/claudebox/command-viewer-real \
      --add-flags $out/libexec/claudebox/command-viewer.js

    # Create wrapper that logs the command-viewer execution
    makeWrapper $out/libexec/claudebox/command-viewer-wrapper.sh $out/libexec/claudebox/command-viewer \
      --set COMMAND_VIEWER_REAL $out/libexec/claudebox/command-viewer-real

    # Create claudebox executable
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/claudebox \
      --add-flags $out/libexec/claudebox/claudebox.js \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.bashInteractive
          pkgs.bubblewrap
          pkgs.tmux
          claudeTools
        ]
      } \
      --prefix PATH : $out/libexec/claudebox

    # Create claude wrapper that references the original
    makeWrapper ${perSystem.self.claude-code}/bin/claude $out/libexec/claudebox/claude \
      --set NODE_OPTIONS "--require=${./command-logger.js}" \
      --inherit-argv0
  ''
