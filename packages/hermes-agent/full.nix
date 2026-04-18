{
  lib,
  flake,
  python3,
  fetchFromGitHub,
  fetchPypi,
  versionCheckHook,
  versionCheckHomeHook,
  buildNpmPackage,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  ripgrep,
  git,
  openssh,
  ffmpeg,
  agent-browser,
  playwright-driver,
}:

(import ./package.nix) {
  inherit
    lib
    flake
    python3
    fetchFromGitHub
    fetchPypi
    versionCheckHook
    versionCheckHomeHook
    buildNpmPackage
    fetchNpmDepsWithPackuments
    npmConfigHook
    nodejs
    ripgrep
    git
    openssh
    ffmpeg
    agent-browser
    playwright-driver
    ;
  withMessagers = true;
  withFull = true;
  attachFullPassthru = false;
}
