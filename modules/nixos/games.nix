{ pkgs, ... }:
{
  programs.steam.enable = true;

  hardware = {
    xpadneo.enable = true;
    steam-hardware.enable = true;
  };

  environment.systemPackages = with pkgs; [ clonehero ];
}
