{ config, ... }:
{
  homeManager.modules.gui.imports = [ config.homeManager.modules.direnv ];

  homeManager.modules.direnv = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global = {
        hide_env_diff = true;
        warn_timeout = "15s";
      };
    };

  };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    ".local/share/direnv"
  ];
}
