# Validate that meta.maintainers resolves for every package.
#
# Package maintainers may reference custom entries from lib/default.nix via
# flake.lib.maintainers.  A typo or missing `flake` passthrough silently
# produces an "undefined variable" that only surfaces when nix-update
# evaluates the attribute later in CI.  This check forces the evaluation
# at `nix flake check` time so the error is caught early.
{
  pkgs,
  flake,
  system,
  ...
}:

let
  inherit (pkgs) lib;

  packages = flake.packages.${system} or { };

  # Force-evaluate meta.maintainers for every package.
  # If any maintainer reference is broken (undefined variable, missing flake
  # passthrough, etc.) this will cause a Nix evaluation error pointing at the
  # offending package—exactly what we want.
  forced = lib.mapAttrsToList (
    _name: pkg: builtins.deepSeq (pkg.meta.maintainers or [ ]) true
  ) packages;
in
pkgs.runCommand "meta-maintainers-check"
  {
    # Force evaluation of all maintainers at derivation-instantiation time
    inherit forced;
  }
  ''
    echo "All package meta.maintainers evaluated successfully"
    touch $out
  ''
