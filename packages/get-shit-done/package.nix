{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "get-shit-done";
  version = "1.18.0";

  src = fetchFromGitHub {
    owner = "gsd-build";
    repo = "get-shit-done";
    rev = "v${version}";
    hash = "sha256-PbvmJkFv1NHd7pc+N4lVh/8ZiQHuPpUpCZLQIX3VZxs=";
  };

  npmDepsHash = "sha256-GokUAV6utbgTzoj3pLb1OWP+MupVtOYzaO0peka6V1s=";

  npmBuildScript = "build:hooks";

  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/get-shit-done-cc/hooks
    cp -r bin commands get-shit-done agents scripts package.json $out/lib/node_modules/get-shit-done-cc/
    cp -r hooks/dist $out/lib/node_modules/get-shit-done-cc/hooks/

    mkdir -p $out/bin
    ln -s $out/lib/node_modules/get-shit-done-cc/bin/install.js $out/bin/get-shit-done
    chmod +x $out/lib/node_modules/get-shit-done-cc/bin/install.js

    runHook postInstall
  '';

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Meta-prompting, context engineering and spec-driven development system for Claude Code";
    homepage = "https://github.com/gsd-build/get-shit-done";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "get-shit-done";
    platforms = platforms.all;
  };
}
