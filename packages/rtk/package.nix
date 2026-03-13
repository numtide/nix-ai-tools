{
  lib,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  jq,
}:

rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.29.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${version}";
    hash = "sha256-QGHCa8rO4YBFXdrz78FhWKFxY7DmRxCXM8iYQv4yTYE=";
  };

  cargoHash = "sha256-gNJjtQah7NFSgFVYJftK19dECzDvLCi2E33na2PtKmc=";

  nativeBuildInputs = [ makeWrapper ];

  doCheck = false;

  postInstall = ''
    install -Dm755 $src/hooks/rtk-rewrite.sh $out/libexec/rtk/hooks/rtk-rewrite.sh
    wrapProgram $out/libexec/rtk/hooks/rtk-rewrite.sh \
      --prefix PATH : ${lib.makeBinPath [ jq ]}:$out/bin
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    changelog = "https://github.com/rtk-ai/rtk/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ vizid ];
    mainProgram = "rtk";
    platforms = platforms.unix;
  };
}
