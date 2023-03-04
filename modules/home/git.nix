{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "TGuimbert";
    userEmail = "33598842+TGuimbert@users.noreply.github.com";
    signing = {
      signByDefault = true;
      key = "11C1D08CC148FEBC";
    };
    aliases = {
      co = "checkout";
			up = "pull --prune --progress";
    };
		extraConfig = {
			diff = {
				colorMoved = "default";
			};
		};
    delta = {
			enable = true;
			options = {
				navigate = true;
				line-numbers = true;
				side-by-side = true;
			};
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
