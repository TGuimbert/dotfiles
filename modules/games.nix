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

      preservation.preserveAt."/persistent".users.tguimbert.directories = [
        ".local/share/Steam"
        ".steam"
        ".clonehero"
        ".config/unity3d/srylain Inc_/Clone Hero"
      ];
    };
}
