{ ... }:
{
  homeManager.modules.base = {
    programs.git = {
      enable = true;

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

  };

  homeManager.modules.gui = {
    # Signing needs gpg + a pinentry, both desktop-only (../gpg.nix); on srv-01
    # it would only make a commit fail.
    programs.git.signing = {
      signByDefault = true;
      key = null;
    };

    # 119 MiB for a diff pager, on a host with no checkout to diff.
    programs.difftastic = {
      enable = true;
      options.background = "dark";
      git.enable = true;
    };
  };
}
