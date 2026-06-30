{ ... }:
{
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        yubikey-manager
        rage
        age-plugin-yubikey
        sops
        bitwarden-cli
        bws
      ];
    };
}
