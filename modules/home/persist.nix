{ ... }:
{
  home.persistence."/persist-home/tguimbert" = {
    directories = [
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      ".dotfiles"
      ".ssh"
      ".local/share/direnv"
      ".mozilla"
      ".cache/tealdeer"
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
