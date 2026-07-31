{ ... }:
{
  homeManager.modules.gui =
    { appearance, ... }:
    {
      programs.foot = {
        enable = true;
        server.enable = true;
        settings.main = {
          shell = "nu -c 'zellij -l welcome'";
          initial-window-mode = "maximized";
          # Colors come from noctalia's theme file (see desktop/noctalia.nix);
          # only the font is fixed here.
          font = "${appearance.monospace.name}:size=${toString appearance.font.size}";
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
