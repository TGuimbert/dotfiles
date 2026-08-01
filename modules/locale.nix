{ ... }:
{
  nixos.modules.base = {
    time.timeZone = "Europe/Paris";
    i18n = {
      defaultLocale = "en_US.UTF-8";

      extraLocaleSettings = {
        LC_ADDRESS = "fr_FR.UTF-8";
        LC_IDENTIFICATION = "fr_FR.UTF-8";
        LC_MEASUREMENT = "fr_FR.UTF-8";
        LC_MONETARY = "fr_FR.UTF-8";
        LC_NAME = "fr_FR.UTF-8";
        LC_NUMERIC = "fr_FR.UTF-8";
        LC_PAPER = "fr_FR.UTF-8";
        LC_TELEPHONE = "fr_FR.UTF-8";
        LC_TIME = "fr_FR.UTF-8";
      };
    };

    console.keyMap = "us";
  };

  nixos.modules.desktop.services.xserver = {
    # us(intl) primary, fr(oss) (AZERTY) as an alternative; toggle with Scroll
    # Lock (KC_SCRL on a Miryoku layer). Still meaningful with the X server off:
    # it feeds /etc/X11 and localectl. Mirrored in modules/desktop/niri.nix and
    # modules/desktop/greeter.nix.
    xkb = {
      layout = "us,fr";
      variant = "intl,oss";
      options = "grp:sclk_toggle";
    };
  };
}
