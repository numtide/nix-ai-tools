{
  mkPackagesFor,
}:
# Builds the packages/ tree against the consumer's `final`, so deps are
# shared with the rest of their system and no second nixpkgs is
# evaluated. Trade-off vs overlays.default: the binary cache only hits
# when the consumer's nixpkgs revision matches ours.
final: _prev: {
  llm-agents = mkPackagesFor final;
}
