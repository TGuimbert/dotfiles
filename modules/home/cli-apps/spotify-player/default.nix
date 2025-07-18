{ osConfig, ... }:
{
  programs.spotify-player = {
    enable = true;
    settings = {
      enable_notify = false;
      cover_img_width = 5;
      cover_img_length = 20;
      cover_img_scale = 0.8;
      client_id_command = {
        command = "cat";
        args = [ "/home/tguimbert/.config/spotify-player/client_id" ];
      };

      device = {
        name = "${osConfig.networking.hostName}-spotify-player";
      };
    };
  };
  home.persistence."/persistent/home/tguimbert" = {
    files = [
      ".config/spotify-player/client_id"
      ".cache/spotify-player/credentials.json"
    ];
  };
}
