{ pkgs, ... }:
{
  config = {
    services.xserver = {
      # Enable the X11 windowing system.
      enable = true;
      # Enable the GNOME Desktop Environment.
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };

    environment.gnome.excludePackages = with pkgs;[
      gnome-tour
    ];

    environment.systemPackages = with pkgs; [
      wl-clipboard
    ];
  };
}
