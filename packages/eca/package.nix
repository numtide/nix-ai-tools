{ pkgs }:

let
  version = "0.78.2";

  # Function to create native binary derivation for each platform
  mkNativeBinary =
    {
      system,
      url,
      hash,
    }:
    pkgs.stdenv.mkDerivation rec {
      pname = "eca";
      inherit version;

      src = pkgs.fetchzip {
        inherit url hash;
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
        license = licenses.asl20;
        maintainers = with maintainers; [ jojo ];
        mainProgram = "eca";
        platforms = [ system ];
      };
    };

in
# Use native binary for all supported platforms
if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
  mkNativeBinary {
    system = "x86_64-linux";
    url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca-native-linux-amd64.zip";
    hash = "sha256-BmlLN2g8JdY/LCxC/9Ho8Gk8uSp1w5vIEghszbXbwk4=";
  }
else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
  mkNativeBinary {
    system = "aarch64-linux";
    url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca-native-linux-aarch64.zip";
    hash = "sha256-spJQ8nNMA5Fn3AvzPMm8zCCAGW/dVlm552KRZRBY2KY=";
  }
else if pkgs.stdenv.hostPlatform.system == "x86_64-darwin" then
  mkNativeBinary {
    system = "x86_64-darwin";
    url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca-native-macos-amd64.zip";
    hash = "sha256-BZvnum0CgiovP1gj0FrQXtLi9zaFQDKGlDwo9Dn7ISw=";
  }
else if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
  mkNativeBinary {
    system = "aarch64-darwin";
    url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca-native-macos-aarch64.zip";
    hash = "sha256-lzABFbA9TPA80F32x/ug/9UyECefsQK273FwwLgkR20=";
  }
else
  # Fallback to JAR version for unsupported platforms
  pkgs.stdenv.mkDerivation rec {
    pname = "eca";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca.jar";
      hash = "sha256-10m85fdmzf2dcfphxcwr3cr985g3wswsm7gvylh30fwr4q2w7g56";
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
      license = licenses.asl20;
      maintainers = with maintainers; [ jojo ];
      mainProgram = "eca";
    };
  }
