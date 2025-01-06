{ pkgs, ... }:
{
  home.packages = with pkgs; [ vault ];

  home.persistence."/persistent/home/tguimbert" = {
    files = [
      ".docker/config.json"
      ".npmrc"
      ".pip/pip.conf"
      ".config/uv/uv.toml"
      ".vault-token"
    ];
    directories = [ ".ssh" ];
  };

  tguimbert.apps.azure-cli.enable = true;

  programs.ssh = {
    enable = true;
    compression = true;
    extraConfig = ''
      SetEnv TERM=xterm-256color
    '';
    includes = [ "private-config" ];
  };
}
