# shellcheck shell=bash

# Collect library directories from buildInputs
declare -a wrapBuddyLibs
declare -a extraWrapBuddyLibs

gatherWrapBuddyLibs() {
  if [[ -d "$1/lib" ]]; then
    wrapBuddyLibs+=("$1/lib")
  fi
}

# shellcheck disable=SC2154
# targetOffset is defined by stdenv
addEnvHooks "$targetOffset" gatherWrapBuddyLibs

# Add extra library search paths manually
addWrapBuddySearchPath() {
  local dir
  for dir in "$@"; do
    if [[ -d $dir ]]; then
      extraWrapBuddyLibs+=("$dir")
    fi
  done
}

# Collect runtime dependencies (for dlopen'd libraries)
# Use: runtimeDependencies = [ libsecret ];
declare -a wrapBuddyRuntimeDeps

addWrapBuddyRuntimeDeps() {
  local dep
  for dep in "$@"; do
    if [[ -d "$dep/lib" ]]; then
      wrapBuddyRuntimeDeps+=("$dep/lib")
    elif [[ -d $dep ]]; then
      wrapBuddyRuntimeDeps+=("$dep")
    fi
  done
}

# Main wrapping function
wrapBuddy() {
  local norecurse=

  while [ $# -gt 0 ]; do
    case "$1" in
    --)
      shift
      break
      ;;
    --no-recurse)
      shift
      norecurse=1
      ;;
    --*)
      echo "wrapBuddy: ERROR: Invalid argument: $1" >&2
      return 1
      ;;
    *) break ;;
    esac
  done

  echo "wrapBuddy: wrapping paths: $*"

  # Add runtimeDependencies from the derivation
  # shellcheck disable=SC2154
  # runtimeDependencies is set by the user's derivation
  if [[ -n ${runtimeDependencies:-} ]]; then
    # shellcheck disable=SC2086
    addWrapBuddyRuntimeDeps $runtimeDependencies
  fi

  wrap-buddy \
    ${norecurse:+--no-recurse} \
    --paths "$@" \
    --libs "${wrapBuddyLibs[@]}" "${extraWrapBuddyLibs[@]}" \
    ${wrapBuddyRuntimeDeps:+--runtime-dependencies "${wrapBuddyRuntimeDeps[@]}"}
}

# Post-fixup hook to run automatically
wrapBuddyPostFixup() {
  if [[ -n ${dontWrapBuddy:-} ]]; then
    return
  fi

  # shellcheck disable=SC2046
  # Word splitting is intentional here to pass multiple output paths
  wrapBuddy -- $(for output in $(getAllOutputNames); do
    [ -e "${!output}" ] || continue
    [ "${output}" = debug ] && continue
    echo "${!output}"
  done)
}

postFixupHooks+=(wrapBuddyPostFixup)
