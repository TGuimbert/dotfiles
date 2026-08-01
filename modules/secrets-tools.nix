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

      programs.nushell.environmentVariables.BWS_SERVER_URL = "https://vault.bitwarden.eu";
    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.files = [
    ".config/Bitwarden CLI/data.json"
  ];
}
