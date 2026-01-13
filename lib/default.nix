{ inputs, ... }:
inputs.nixpkgs.lib.extend (
  _final: prev: {
    maintainers = prev.maintainers // {
      ypares = {
        github = "YPares";
        githubId = 1377233;
        name = "Yves Parès";
      };
    };
  }
)
