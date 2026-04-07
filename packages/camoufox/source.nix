{ }:
let
  firefoxVersion = "146.0.1";
  release = "beta.25";
in
{
  version = "${firefoxVersion}-${release}";

  upstream = {
    owner = "CloverLabsAI";
    repo = "camoufox";
    rev = "dfa62f70701e1a0b4ca44798b390b805d0e0bd4e";
    hash = "sha256-eQvCYt6H+Qt85ImQUvjGz76YnsekguxfMho2kbs3gkI=";
  };

  firefox = {
    version = firefoxVersion;
    hash = "sha256-6WeKDoRzkjlT4dwxLDeRkGhiO2qiCtreFiZgSSWBkes=";
  };
}
