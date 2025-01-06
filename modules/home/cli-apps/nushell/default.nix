{ pkgs, lib, ... }:
let
  private_config_path = ".config/nushell/private.nu";
  pluginNamesNixpkgs = [ "formats" ];
  activateNushellPluginsNuScript = pkgs.writeTextFile {
    name = "activateNushellPlugins";
    destination = "/bin/activateNushellPlugins.nu";
    text = ''
      #!/usr/bin/env nu
      ${lib.concatStringsSep "\n" (
        map (x: "plugin add ${pkgs.nushellPlugins.${x}}/bin/nu_plugin_${x}") pluginNamesNixpkgs
      )}
    '';
  };

  msgPackz = pkgs.runCommand "nushellMsgPackz" { } ''
    mkdir -p "$out"
    # After some experimentation, I determined that this only works if --plugin-config is FIRST
    ${pkgs.nushell}/bin/nu --plugin-config "$out/plugin.msgpackz" ${activateNushellPluginsNuScript}/bin/activateNushellPlugins.nu
  '';
in
{
  programs = {
    nushell = {
      enable = true;
      configFile.source = ./config.nu;
      environmentVariables = {
        BWS_SERVER_URL = "https://vault.bitwarden.eu";
        SHELL = pkgs.nushell;
      };
      extraEnv = ''
        if (not ("~/${private_config_path}" | path exists)) {
          touch ~/${private_config_path}
        }
      '';
      extraConfig = ''
        source ~/${private_config_path}
        use ${pkgs.nu_scripts}/share/nu_scripts/aliases/eza/eza-aliases.nu *
      '';
    };
    carapace = {
      enable = true;
    };
  };

  # See https://github.com/nushell/nushell/discussions/12997#discussioncomment-9638977
  xdg.configFile."nushell/plugin.msgpackz".source = "${msgPackz}/plugin.msgpackz";

  home = {
    persistence."/persistent/home/tguimbert" = {
      files = [
        ".config/nushell/history.txt"
        private_config_path
      ];
    };
  };
}
