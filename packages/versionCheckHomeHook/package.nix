{
  lib,
  makeSetupHook,
}:

makeSetupHook {
  name = "version-check-home-hook";
  meta = {
    description = "Setup hook that provides a writable HOME for versionCheckHook";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
} ./version-check-home.sh
