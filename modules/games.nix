{ ... }:
{
  nixos.modules.games =
    { pkgs, ... }:
    {
      programs.steam.enable = true;

      hardware = {
        xpadneo.enable = true;
        steam-hardware.enable = true;
      };

      environment.systemPackages = with pkgs; [ clonehero ];

      home-manager.users.tguimbert.home.persistence."/persistent".directories = [
        ".local/share/Steam"
        ".steam"
        ".clonehero"
        ".config/unity3d/srylain Inc_/Clone Hero"
      ];
    };
}
