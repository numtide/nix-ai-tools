{ inputs, ... }:
inputs.nixpkgs.lib.extend (
  _final: prev: {
    maintainers = prev.maintainers // {
      ypares = {
        github = "YPares";
        githubId = 1377233;
        name = "Yves Parès";
      };
      Chickensoupwithrice = {
        github = "Chickensoupwithrice";
        githubId = 22575913;
        name = "Anish Lakhwara";
      };
      mulatta = {
        github = "mulatta";
        githubId = 67085791;
        name = "Seungwon Lee";
      };
    };
  }
)
