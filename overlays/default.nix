{
  packages,
  excludedPackages,
}:
final: _prev: {
  llm-agents = builtins.removeAttrs (packages.${final.stdenv.hostPlatform.system} or { }
  ) excludedPackages;
}
