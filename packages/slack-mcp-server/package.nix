{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_24,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;

  src = fetchFromGitHub {
    owner = "korotovsky";
    repo = "slack-mcp-server";
    rev = "v${version}";
    inherit hash;
  };
in
(buildGoModule.override { go = go_1_24; }) {
  pname = "slack-mcp-server";
  inherit version vendorHash src;

  subPackages = [ "cmd/slack-mcp-server" ];

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  passthru.category = "MCP Servers";

  meta = {
    description = "MCP server for Slack with stealth mode, OAuth, DMs, and smart history";
    homepage = "https://github.com/korotovsky/slack-mcp-server";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ garbas ];
    mainProgram = "slack-mcp-server";
  };
}
