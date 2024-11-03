{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # vault
  ];

  home.persistence."/persistent/home/tguimbert" = {
    files = [
      ".docker/config.json"
      ".npmrc"
      ".pip/pip.conf"
      ".vault-token"
    ];
    directories = [ ".ssh" ];
  };

  tguimbert.apps.azure-cli.enable = true;

  programs.ssh = {
    enable = true;
    compression = true;
    includes = [ "private-config" ];
  };
}
