{ config, pkgs, ... }:

{
  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "gnome3";
  };

	programs.gpg.enable = true;
}
