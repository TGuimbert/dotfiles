{ pkgs, ... }:
{
  config = {
    services.pcscd.enable = true;

    environment.systemPackages = with pkgs; [
      pinentry-gnome
    ];
  };
}
