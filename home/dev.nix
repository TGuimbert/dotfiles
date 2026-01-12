{ pkgs, ... }:
{
  programs = {
    git = {
      enable = true;
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

      settings = {
        user = {
          name = "TGuimbert";
          email = "33598842+TGuimbert@users.noreply.github.com";
        };
        alias = {
          co = "checkout";
          up = "pull --prune --progress";
          lol = "log --oneline --graph --all";
        };
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

      ignores = [
        ".devenv/"
        ".direnv/"
        ".envrc"
      ];
    };

    difftastic = {
      enable = true;
      options.background = "dark";
      git.enable = true;
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
      enableDefaultConfig = false;
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";

        compression = true;
        setEnv.TERM = "xterm-256color";
      };
      includes = [ "private-config" ];
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  home.persistence."/persistent" = {
    directories = [
      ".ssh"
    ];
  };
}
