{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "TGuimbert";
    userEmail = "33598842+TGuimbert@users.noreply.github.com";
    signing = {
      signByDefault = true;
      key = null;
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
      editor = "hx";
      aliases = {
        pc = "pr create --assignee @me";
        co = "pr checkout";
        pv = "pr view";
        pw = "pr view --web";
      };
    };
    extensions = with pkgs; [
      gh-dash
      gh-eco
      gh-markdown-preview
    ];
  };
}
