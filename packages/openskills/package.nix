{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "openskills";
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "numman-ali";
    repo = "openskills";
    rev = "v${version}";
    hash = "sha256-YSfLzaoHZIDfpCcLBf9ES5dhxweesjqkfeSfClZNAzE=";
  };

  npmDepsHash = "sha256-1j+cgWoHpbrM9pf5CyHTy6lfNRoDo5PNtOaGX4y4QnI=";

  meta = {
    description = "Universal skills loader for AI coding agents - install and load Anthropic SKILL.md format skills in any agent";
    homepage = "https://github.com/numman-ali/openskills";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = [ ];
    mainProgram = "openskills";
    platforms = lib.platforms.all;
  };
}
