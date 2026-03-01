{
  lib,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  jq,
}:

rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.23.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${version}";
    hash = "sha256-yoCfiPCAOJp2nwhr50vfwCf/ZqbOmLVbq0b3kVUURFk=";
  };

  cargoHash = "sha256-iO78HENuBjb6u+GaMsab/Hs+ypm8lCSxwpny9ak1djY=";

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
