{
  lib,
  config,
  ...
}:
{
  options.features.audio.enable = lib.mkEnableOption "audio (pipewire)" // {
    default = true;
  };

  config = lib.mkIf config.features.audio.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
