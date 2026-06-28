{ ... }:
{
  homeManager.modules.gui = {
    programs.foot = {
      enable = true;
      server.enable = true;
      settings.main = {
        shell = "nu -c 'zellij -l welcome'";
        initial-window-mode = "maximized";
        font = "IosevkaTerm Nerd Font:size=12";
      };
    };

    programs.bash.enable = true;

    home.sessionPath = [ "$HOME/.local/bin" ];

    home.sessionVariables = {
      ZELLIJ_AUTO_ATTACH = "true";
      ZELLIJ_AUTO_EXIT = "true";
    };

    home.persistence."/persistent".files = [ ".bash_history" ];
  };
}
