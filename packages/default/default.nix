{
  pkgs,
  perSystem,
  ...
}:
let
  allPackages = perSystem.self;

  # Filter to visible, runnable packages
  visibleNames = builtins.filter (
    name: name != "default" && !(allPackages.${name}.passthru.hideFromDocs or false)
  ) (builtins.attrNames allPackages);

  # Build "name\tdescription" lines
  packageLines = map (name: "${name}\t${allPackages.${name}.meta.description or ""}") visibleNames;

  packageList = builtins.concatStringsSep "\n" packageLines;
in
pkgs.callPackage ./package.nix { inherit packageList; }
