{ pkgs, ... }:
# Re-export of nixpkgs' buildNpmPackage with an eval-time guard.
#
# Several packages here set `npmDepsFetcherVersion = 2`, whose FOD output (and
# thus the committed npmDepsHash) depends on prefetch-npm-deps caching
# packuments. On nixpkgs revisions predating that support the attribute is
# silently ignored and the FOD falls back to v1 behaviour, surfacing only as a
# confusing `hash mismatch in fixed-output derivation …-npm-deps.drv` (#4320).
#
# The guard fires for every consumption path that swaps out nixpkgs
# (overlays.shared-nixpkgs, `inputs.llm-agents.inputs.nixpkgs.follows`, direct
# callPackage), because blueprint builds perSystem.self against whatever `pkgs`
# is in effect.
let
  inherit (pkgs) lib;
  hasFetcherVersion = (lib.functionArgs pkgs.fetchNpmDeps) ? fetcherVersion;
  msg = ''
    llm-agents.nix: this nixpkgs is too old for our npm packages.

    fetchNpmDeps lacks the `fetcherVersion` argument, so the committed
    npmDepsHash (computed with fetcherVersion = 2) cannot match. You are
    likely on nixos-25.11 or an early-2026 unstable via
    `overlays.shared-nixpkgs` or `inputs.llm-agents.inputs.nixpkgs.follows`.

    Either use `overlays.default` / the flake packages directly, or bump
    nixpkgs to at least 203662a570c4 (2026-02-15). See
    https://github.com/numtide/llm-agents.nix/issues/4320.
  '';
in
# A real (empty) derivation so blueprint / buildbot can enumerate and "build"
# it, plus a __functor that forwards to the actual builder so
# `perSystem.self.buildNpmPackage { … }` works in package.nix.
pkgs.emptyDirectory.overrideAttrs { name = "buildNpmPackage-guard"; }
// {
  __functor =
    _:
    assert lib.assertMsg hasFetcherVersion msg;
    pkgs.buildNpmPackage;
  override = pkgs.buildNpmPackage.override;
  passthru.hideFromDocs = true;
  meta = {
    description = "nixpkgs buildNpmPackage with an eval guard for fetcherVersion=2";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
