{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "groq-code-cli";
  version = "1.0.2-unstable-2025-08-22";

  src = fetchFromGitHub {
    owner = "build-with-groq";
    repo = "groq-code-cli";
    rev = "d79a9c59f31028f81bbf3221dc7b5fe4b37a9cef";
    hash = "sha256-ZER7Wnz9DOnVLGggpYugBFGFXC6Vbjkfi/sDaKKgJBg=";
  };

  npmDepsHash = "sha256-oJw1V1/oqfik5cHnlnIQyyIpL+vEvp/Yj8Oe+fxQ5Ls=";

  postPatch = ''
    # Update package-lock.json with the one we generated
    cp ${./package-lock.json} package-lock.json
  '';

  meta = with lib; {
    description = "A highly customizable, lightweight, and open-source coding CLI powered by Groq for instant iteration";
    homepage = "https://github.com/build-with-groq/groq-code-cli";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "groq";
    platforms = platforms.all;
  };
}
