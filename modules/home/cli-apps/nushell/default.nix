{ pkgs, ... }:
{
  programs = {
    nushell = {
      enable = true;
      configFile.source = ./config.nu;
      extraConfig = ''
        plugin add ${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats
        plugin use formats

        const private_config_path = /home/tguimbert/.config/nushell/private.nu
        touch $private_config_path
        source $private_config_path
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
