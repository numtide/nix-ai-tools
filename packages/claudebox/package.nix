{
  pkgs,
  # Make claude-code overridable
  claude-code,
  # Keep this so package.nix can be copied into llm-agents.nix
  sourceDir ? ./src,
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;

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

  # Platform-specific sandbox tools
  sandboxTools = if isLinux then [ pkgs.bubblewrap ] else [ ];

  # Seatbelt profile for macOS (only installed on darwin)
  seatbeltProfile = "${sourceDir}/seatbelt.sbpl";
in
pkgs.runCommand "claudebox"
  {
    buildInputs = [ pkgs.makeWrapper ];
    meta = with pkgs.lib; {
      mainProgram = "claudebox";
      description = "Sandboxed environment for Claude Code";
      homepage = "https://github.com/numtide/claudebox";
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.linux ++ platforms.darwin;
    };
  }
  ''
    mkdir -p $out/bin $out/share/claudebox $out/libexec/claudebox

    # Install claudebox launcher script
    cp ${sourceDir}/claudebox.js $out/libexec/claudebox/claudebox.js

    # Install command-viewer script
    cp ${sourceDir}/command-viewer.js $out/libexec/claudebox/command-viewer.js

    # Install wrapper script
    cp ${sourceDir}/command-viewer-wrapper.sh $out/libexec/claudebox/command-viewer-wrapper.sh
    chmod +x $out/libexec/claudebox/command-viewer-wrapper.sh

    # Install seatbelt profile for macOS
    cp ${seatbeltProfile} $out/share/claudebox/seatbelt.sbpl

    # Create the real command-viewer executable
    makeWrapper ${pkgs.nodejs}/bin/node $out/libexec/claudebox/command-viewer-real \
      --add-flags $out/libexec/claudebox/command-viewer.js

    # Create wrapper that logs the command-viewer execution
    makeWrapper $out/libexec/claudebox/command-viewer-wrapper.sh $out/libexec/claudebox/command-viewer \
      --set COMMAND_VIEWER_REAL $out/libexec/claudebox/command-viewer-real

    # Create claudebox executable with platform-specific configuration
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/claudebox \
      --add-flags $out/libexec/claudebox/claudebox.js \
      --prefix PATH : ${
        pkgs.lib.makeBinPath (
          [
            pkgs.bashInteractive
            pkgs.tmux
            claudeTools
          ]
          ++ sandboxTools
        )
      } \
      --prefix PATH : $out/libexec/claudebox \
      ${if isDarwin then "--set CLAUDEBOX_SEATBELT_PROFILE $out/share/claudebox/seatbelt.sbpl" else ""}

    # Create claude wrapper that references the original
    makeWrapper ${claude-code}/bin/claude $out/libexec/claudebox/claude \
      --set NODE_OPTIONS "--require=${sourceDir}/command-logger.js" \
      --inherit-argv0
  ''
