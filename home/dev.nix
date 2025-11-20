{ pkgs, ... }:
{
  programs = {
    git = {
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
        lol = "log --oneline --graph --all";
      };

      extraConfig = {
        core = {
          compression = 9;
          whitespace = "error";
          preloadindex = true;
        };
        advice = {
          addEmptyPathspec = false;
          pushNonFastForward = false;
          statusHints = false;
        };
        init = {
          defaultBranch = "main";
        };
        status = {
          branch = true;
          short = true;
          showStash = true;
          showUntrackedFiles = "all";
        };
        diff = {
          contexte = 3;
          renames = "copies";
          interHunkContext = 10;
        };
        push = {
          autoSetupRemote = true;
          default = "current";
          followTags = true;
        };
        pull = {
          default = "current";
          rebase = true;
        };
        rebase = {
          autoStash = true;
          missingCommitsCheck = "warn";
        };
        log = {
          abbrevCommit = true;
          graphColors = "blue,yellow,cyan,magenta,green,red";
        };
        branch = {
          sort = "-committerdate";
        };
        tag = {
          sort = "-taggerdate";
        };
        pager = {
          branch = false;
          tag = false;
        };
      };

      difftastic = {
        enable = true;
        background = "dark";
      };

      ignores = [
        ".devenv/"
        ".direnv/"
        ".envrc"
      ];
    };

    nushell.shellAliases = {
      gs = "git status";
      gd = "git diff";
      gds = "git diff --staged";
      ga = "git add";
      gap = "git add --patch";
      gc = "git commit";
      gca = "git commit --amend --no-edit";
      gce = "git commit --amend";
      gp = "git push";
      gu = "git pull";
      gco = "git checkout";
      gsw = "git switch";
      gn = "git switch --create";
      gl = "git log --graph --all --pretty=format:\"%C(magenta)%h %C(white) %an  %ar%C(blue)  %D%n%s%n\"";
      gb = "git branch";
    };

    gh = {
      enable = true;
      gitCredentialHelper.enable = false;
      settings = {
        git_protocol = "ssh";
        editor = "hx";
        aliases = {
          pc = "pr create --assignee @me";
          co = "pr checkout";
          pv = "pr view";
          pw = "pr view --web";
          pcw = "pr checks --web";
        };
      };
      extensions = with pkgs; [
        gh-dash
        gh-eco
        gh-markdown-preview
      ];
    };

    gpg = {
      enable = true;
      publicKeys = [
        {
          source = builtins.fetchurl {
            url = "https://github.com/TGuimbert.gpg";
            sha256 = "07b7gfhr13923jv7vfdnq80rpahgdzd8anxy07876395ywsrnvkb";
          };
          trust = 5;
        }
      ];
      scdaemonSettings = {
        reader-port = "Yubico Yubi";
        disable-ccid = true;
      };
    };

    ssh = {
      enable = true;
      compression = true;
      extraConfig = ''
        SetEnv TERM=xterm-256color
      '';
      includes = [ "private-config" ];
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  home = {
    packages = with pkgs; [
      azure-cli
    ];

    persistence."/persistent/home/tguimbert" = {
      directories = [
        ".azure"
        ".ssh"
      ];
    };
  };
}
