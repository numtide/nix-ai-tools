{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage {
  pname = "groq-code-cli";
  version = "0-unstable-2025-09-05";

  src = fetchFromGitHub {
    owner = "build-with-groq";
    repo = "groq-code-cli";
    rev = "a303eb4be01a53aaf3fbf319636e2b608e80aeca";
    hash = "sha256-AyuGMMFcMQXclRbR1AJstop3QRD4lBzXI6eAAKOO3t0=";
  };

  npmDepsHash = "sha256-0ly0yumpqQPGUcMvO0x3ZGZ6X/dVM48X4QapXR05Ugk=";

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
