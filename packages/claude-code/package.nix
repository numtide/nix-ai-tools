{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_20,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.0.14";

  nodejs = nodejs_20; # required for sandboxed Nix builds on Darwin

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-U/wd00eva/qbSS4LpW1L7nmPW4dT9naffeMkHQ5xr5o=";
  };

  npmDepsHash = "sha256-AwDDmDLd13+vfzUfLgbLL05RqgGdrlIvPJ5tBMYq2cU=";

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  AUTHORIZED = "1";

  # Disable auto-updates and telemetry by wrapping the binary
  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_TELEMETRY 1 \
      --unset DEV
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    changelog = "https://github.com/anthropics/claude-code/releases";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [
      malo
      omarjatoi
    ];
    mainProgram = "claude";
    platforms = platforms.all;
  };
}
