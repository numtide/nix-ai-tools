{ pkgs }:

let
  version = "0.72.2";
  
  # For x86_64-linux, use native binary
  nativeBinary = pkgs.stdenv.mkDerivation rec {
    pname = "eca";
    inherit version;

    src = pkgs.fetchzip {
      url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca-native-linux-amd64.zip";
      hash = "sha256-0WdAHyghCTDxDOtnODhBOGqpHPOVEskqvCLY3HNCEJg=";
      stripRoot = false;
    };

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp $src/eca $out/bin/eca
      chmod +x $out/bin/eca
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Editor Code Assistant (ECA) - AI pair programming capabilities agnostic of editor";
      homepage = "https://github.com/editor-code-assistant/eca";
      license = licenses.mit;
      maintainers = with maintainers; [ jojo ];
      mainProgram = "eca";
      platforms = [ "x86_64-linux" ];
    };
  };

  # For other platforms, use JAR version
  jarVersion = pkgs.stdenv.mkDerivation rec {
    pname = "eca";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca.jar";
      hash = "sha256-y9kOX0JlEma2r4Muxl+09foVYuC/AXl2boQ3U2G9CWo=";
    };

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    buildInputs = [
      pkgs.jre
    ];

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/lib
      cp $src $out/lib/eca.jar

      cat > $out/bin/eca << EOF
      #!${pkgs.stdenv.shell}
      export JAVA_HOME="${pkgs.jre}"
      export PATH="${pkgs.jre}/bin:\$PATH"
      exec "${pkgs.jre}/bin/java" -jar "$out/lib/eca.jar" "\$@"
      EOF

      chmod +x $out/bin/eca
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Editor Code Assistant (ECA) - AI pair programming capabilities agnostic of editor";
      homepage = "https://github.com/editor-code-assistant/eca";
      license = licenses.mit;
      maintainers = with maintainers; [ jojo ];
      mainProgram = "eca";
      platforms = [ "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    };
  };

in
if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
  nativeBinary
else
  jarVersion
