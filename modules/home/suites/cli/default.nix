{ pkgs, ... }:
{
  home.packages = with pkgs; [
    yubikey-manager
    rage
    age-plugin-yubikey
    bitwarden-cli
    jq
    dig
    dprint
  ];

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      config = {
        global = {
          hide_env_diff = true;
          warn_timeout = "15s";
        };
      };
    };
  };
}
