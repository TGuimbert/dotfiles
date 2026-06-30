{ ... }:
{
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      programs.gh = {
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

      home.persistence."/persistent".files = [ ".config/gh/hosts.yml" ];
    };
}
