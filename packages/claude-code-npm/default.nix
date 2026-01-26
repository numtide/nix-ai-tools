{ pkgs, perSystem, ... }:
(pkgs.lib.warn "claude-code-npm is deprecated, use claude-code instead" perSystem.self.claude-code)
.overrideAttrs
  (old: {
    passthru = (old.passthru or { }) // {
      hideFromDocs = true;
    };
  })
