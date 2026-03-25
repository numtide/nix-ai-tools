# Workaround for https://github.com/numtide/llm-agents.nix/issues/3409
# Removal tracked in https://github.com/numtide/llm-agents.nix/issues/3451
#
# onnxruntime 1.23.2 fails on Darwin with -Werror,-Wunused-result because
# protobuf 34 added [[nodiscard]] to SerializeToString. The nixpkgs
# protobuf34-nodiscard.patch is incomplete for 1.23.2 (misses the test
# suite). Fixed upstream by NixOS/nixpkgs#501901 (onnxruntime 1.24.4)
# but that has not reached nixpkgs-unstable yet.
#
# Rather than backporting the version bump, suppress the warning. This
# override becomes a no-op once nixpkgs-unstable advances and can be
# removed at that point — see issue #3451 for the cleanup checklist.
#
# The override is Darwin-only: applying it on Linux would force a rebuild
# from source instead of substituting from cache.nixos.org, and the test
# suite (QDQTransformerTests/NhwcTransformerTests) fails on builders that
# lack AVX-VNNI.
{
  lib,
  stdenv,
  onnxruntime,
}:
if lib.versionAtLeast onnxruntime.version "1.24" || !stdenv.hostPlatform.isDarwin then
  onnxruntime
else
  onnxruntime.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString [
        (old.env.NIX_CFLAGS_COMPILE or "")
        "-Wno-error=unused-result"
      ];
    };
  })
