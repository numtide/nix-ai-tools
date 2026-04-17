{
  lib,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  jq,
}:

rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.37.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${version}";
    hash = "sha256-xmsMsZ2gLogXBliNlzRGt1UN7tdoBNg3iIsjsanSLzU=";
  };

  cargoHash = "sha256-b/U8enTKlkQNUvK4baBOPu0WGU13O/peJ7TnNRdoMdM=";

  nativeBuildInputs = [ makeWrapper ];

  doCheck = false;

  postInstall = ''
    mkdir -p $out/libexec/rtk
    cp -r $src/hooks $out/libexec/rtk/hooks
    chmod -R +w $out/libexec/rtk/hooks
    find $out/libexec/rtk/hooks -name '*.sh' -exec chmod 755 {} \;
    for f in $(find $out/libexec/rtk/hooks -name '*.sh'); do
      wrapProgram "$f" \
        --prefix PATH : ${lib.makeBinPath [ jq ]}:$out/bin
    done
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
