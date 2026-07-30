{ ... }:
{
  nixos.modules.desktop = {
    time.timeZone = "Europe/Paris";
    i18n = {
      defaultLocale = "en_US.UTF-8";

      # GNOME's nixpkgs module switches ibus on by default, but no input method is
      # wanted here: no engines are configured and the layouts below are plain xkb,
      # which niri and GNOME drive themselves. Off also drops GTK_IM_MODULE /
      # QT_IM_MODULE, so GTK and Qt apps take Wayland's text-input-v3 instead.
      inputMethod.enable = false;

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

    services.xserver = {
      # us(intl) primary, fr(oss) (AZERTY) as an alternative; toggle with
      # Scroll Lock (KC_SCRL on a Miryoku layer). Mirrored in modules/niri/niri.nix.
      xkb = {
        layout = "us,fr";
        variant = "intl,oss";
        options = "grp:sclk_toggle";
      };
    };
    console.keyMap = "us";
  };
}
