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

  };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.files = [
    ".bash_history"
  ];
}
