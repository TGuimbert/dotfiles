{ ... }:
{
  nixos.modules.desktop = {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  homeManager.modules.gui = {
    home.persistence."/persistent".directories = [ ".local/state/wireplumber" ];
  };
}
