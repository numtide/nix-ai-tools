{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "groq-code-cli";
  version = "1.0.2-unstable-2025-08-19";

  src = fetchFromGitHub {
    owner = "build-with-groq";
    repo = "groq-code-cli";
    rev = "4f646d339d69520f96ad21a7724b139e9fab697f";
    hash = "sha256-yGQb2tCgvkNsqOakESlcwf6EdFmy7ZvzyF671ml0duc=";
  };

  npmDepsHash = "sha256-6ZqY4BQ4x6LN7DBYVs6UlvHqTagW6yXCHfh5jRGIEB8=";

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
