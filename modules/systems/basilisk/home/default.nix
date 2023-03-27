{ pkgs, ... }: {
  home.packages = with pkgs; [
    zoom-us
    slack
    chromium
  ];

  home.persistence."/persist-home/tguimbert" = {
    directories = [
      ".config/Slack"
      ".zoom"
    ];
    files = [
      ".config/zoom.conf"
      ".config/zoomus.conf"
    ];
    allowOther = true;
  };

  scortex = {
    impermanence.enable = true;
    devOpsTools.enable = true;
  };
}
