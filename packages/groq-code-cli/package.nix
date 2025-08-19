{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "groq-code-cli";
  version = "1.0.2-unstable-2025-08-18";

  src = fetchFromGitHub {
    owner = "build-with-groq";
    repo = "groq-code-cli";
    rev = "26ff64e4df9d96917ff542522aeebe5eafebb5f8";
    hash = "sha256-cWnfaj3By3Trmj/IUE8sGBXcz4eRBAksj0oIOmE+KpI=";
  };

  npmDepsHash = "sha256-QOasWavKq408S9g4Ob2GtTiujARCzqLVSENW/eFYxv0=";

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
