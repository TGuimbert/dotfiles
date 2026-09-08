{ config, ... }:
{
  homeManager.modules = {
    base.imports = [ config.homeManager.modules.bash ];

    bash = {
      programs.bash.enable = true;
      home.sessionPath = [ "$HOME/.local/bin" ];
    };

    gui =
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

      };

  };

  nixos.modules.base.preservation.preserveAt."/persistent".users.tguimbert.files = [
    ".bash_history"
  ];
}
