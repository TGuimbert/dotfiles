{ pkgs, ... }:
{
  programs = {
    nushell = {
      enable = true;
      configFile.source = ./config.nu;
      extraConfig = ''
        plugin add ${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats
        plugin use formats
      '';
    };
    carapace = {
      enable = true;
    };
  };

  home = {

    # packages = with pkgs; [ nushellPlugins.formats ];

    persistence."/persistent/home/tguimbert" = {
      files = [
        ".config/nushell/history.txt"
        ".config/nushell/private.nu"
      ];
    };
  };
}
