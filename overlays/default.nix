{
  packages,
}:
final: _prev: {
  llm-agents = packages.${final.stdenv.hostPlatform.system} or { };
}
