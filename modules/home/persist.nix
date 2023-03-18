{ ... }:
{
  home.persistence."/persist-home/tguimbert" = {
    directories = [
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      ".config/spotify"
      ".dotfiles"
      ".ssh"
      ".local/share/direnv"
      ".mozilla"
      ".cache/tealdeer"
      ".cache/spotify"
      ".local/state/wireplumber"
    ];
    files = [
      ".local/share/fish/fish_history"
      ".config/monitors.xml"
      ".config/gh/hosts.yml"
    ];
    allowOther = true;
  };
}
