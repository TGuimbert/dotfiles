{ ... }:
{
  home.persistence."/persist-home/tguimbert" = {
    directories = [
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      "Workspace"
      ".config/discord"
      ".config/spotify"
      ".doppler"
      ".dotfiles"
      ".ssh"
      ".gnupg/private-keys-v1.d/"
      ".kube"
      ".local/share/direnv"
      ".local/share/zoxide"
      ".minikube"
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
