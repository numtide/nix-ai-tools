{
  lib,
  python3,
  fetchFromGitHub,
}:

let
  python = python3.override {
    self = python;
    packageOverrides = _final: prev: {
      # Transitive dep via fastmcp -> py-key-value-aio. Its dynamodb tests
      # break against the moto/aiobotocore-3.x combo in current
      # nixpkgs-unstable ("Duplicate 'Server' header"). Fixed upstream in
      # NixOS/nixpkgs#513680; drop this override once that lands in our pin
      # (tracking: numtide/llm-agents.nix#4343).
      aioboto3 = prev.aioboto3.overridePythonAttrs { doCheck = false; };
    };
  };

in
python.pkgs.buildPythonApplication rec {
  pname = "code-review-graph";
  version = "2.3.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tirth8205";
    repo = "code-review-graph";
    rev = "v${version}";
    hash = "sha256-2U+NfPOb2A/gmqzRUQ/80C5EhOHPM4YpGilZmVSTY/g=";
  };

  build-system = with python.pkgs; [
    hatchling
  ];

  # Upstream pins tree-sitter-language-pack <1 and watchdog <6, but nixpkgs
  # has advanced to 1.x and 6.x. The runtime deps check is overly strict.
  pypaBuildFlags = [ "--skip-dependency-check" ];

  dependencies = with python.pkgs; [
    mcp
    fastmcp
    tree-sitter
    tree-sitter-language-pack
    networkx
    watchdog
  ];

  # Relax version constraints — nixpkgs versions are newer but compatible.
  pythonRelaxDeps = [
    "tree-sitter-language-pack"
    "watchdog"
  ];

  pythonImportsCheck = [ "code_review_graph" ];

  passthru.category = "Code Review";

  meta = with lib; {
    description = "Local knowledge graph for AI coding agents — builds persistent map of your codebase for token-efficient code reviews";
    homepage = "https://github.com/tirth8205/code-review-graph";
    changelog = "https://github.com/tirth8205/code-review-graph/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ aldoborrero ];
    # Transitive dependency `lupa` ships a pre-built LuaJIT that only links
    # on x86_64, so we exclude aarch64-linux.
    platforms = [ "x86_64-linux" ];
    mainProgram = "code-review-graph";
  };
}
