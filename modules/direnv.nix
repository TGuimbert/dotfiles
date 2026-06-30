{ ... }:
{
  homeManager.modules.gui = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global = {
        hide_env_diff = true;
        warn_timeout = "15s";
      };
    };

    home.persistence."/persistent".directories = [ ".local/share/direnv" ];
  };
}
