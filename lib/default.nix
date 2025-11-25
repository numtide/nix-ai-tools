{ inputs, ... }:
inputs.nixpkgs.lib.extend (
  _final: prev: {
    maintainers = prev.maintainers // {
      ryoppippi = {
        github = "ryoppippi";
        githubId = 1560508;
        name = "ryoppippi";
      };
    };
  }
)
