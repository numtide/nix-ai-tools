# shellcheck shell=bash
# Setup hook that relaxes go.mod version constraints to match the Go toolchain
# used by the build.  This prevents "go.mod requires go >= X.Y.Z" errors when
# upstream pins a newer patch version than nixpkgs ships.
#
# What this hook does:
#   1. Patches the go directive in go.mod to match the running Go version.
#   2. Removes the toolchain directive so Go does not try to switch toolchains.
#
# This is sufficient when the *top-level* go.mod is the only one that pins a
# newer version.  When transitive dependencies also require a newer Go, use
# go-bin (our prebuilt latest-patch Go package) instead:
#
#   buildGoModule.override { go = go-bin; }

unpinGoModVersion() {
  if [[ ! -f go.mod ]]; then
    return
  fi

  local goVersion
  goVersion="$(go env GOVERSION)"
  goVersion="${goVersion#go}"

  echo "unpinGoModVersionHook: setting go.mod go directive to $goVersion"
  sed -i "s/^go .*/go $goVersion/" go.mod

  if grep -q '^toolchain ' go.mod; then
    echo "unpinGoModVersionHook: removing toolchain directive from go.mod"
    sed -i '/^toolchain /d' go.mod
  fi
}

postPatchHooks+=(unpinGoModVersion)
