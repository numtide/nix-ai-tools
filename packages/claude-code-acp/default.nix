{
  pkgs,
  perSystem,
  ...
}:
pkgs.lib.warnOnInstantiate "'claude-code-acp' has been renamed to 'claude-agent-acp'. Please update your references." perSystem.self.claude-agent-acp
// {
  passthru.hideFromDocs = true;
}
