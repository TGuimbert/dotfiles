{ ... }:
{
  homeManager.modules.gui = {
    programs.git = {
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

    programs.difftastic = {
      enable = true;
      options.background = "dark";
      git.enable = true;
    };
  };
}
