{ ... }:
{
  programs.git = {
    enable = true;
    userName = "TGuimbert";
    userEmail = "33598842+TGuimbert@users.noreply.github.com";
    signing = {
      signByDefault = true;
      key = "11C1D08CC148FEBC";
    };

    # Modify commit email for work related repos
    includes = [
      {
        condition = "hasconfig:remote.*.url:git@github.com:scortexio/**";
        contents = {
          user = {
            email = "tguimbert@scortex.io";
          };
        };
      }
    ];

    aliases = {
      co = "checkout";
      up = "pull --prune --progress";
    };

    extraConfig = {
      diff = {
        colorMoved = "default";
      };
    };

    difftastic = {
      enable = true;
      background = "dark";
    };
  };

  programs.gh = {
    enable = true;
    enableGitCredentialHelper = false;
    settings = {
      git_protocol = "ssh";

      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };
}
