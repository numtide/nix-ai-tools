{
  inputs,
  pkgs,
  ...
}:
# A derivation that references all flake inputs to ensure they get cached
pkgs.runCommand "flake-inputs" { } ''
  echo ${pkgs.lib.concatMapStringsSep " " (name: inputs.${name}) (builtins.attrNames inputs)} > $out
''
// {
  passthru.hideFromDocs = true;
}
