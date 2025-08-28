{ inputs, ... }:
{
  imports = [ inputs.impermanence.nixosModules.home-manager.impermanence ];
  home.persistence."/persistent/home/tguimbert" = {
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
      ".gnupg"
      ".kube"
      ".local/share/Anki2"
      ".local/share/direnv"
      ".local/share/keyrings"
      ".local/share/zoxide"
      ".minikube"
      ".mozilla"
      ".cache/tealdeer"
      ".cache/spotify"
      ".cache/pip"
      ".cache/pre-commit"
      ".config/obsidian"
      ".local/state/wireplumber"
      ".local/share/fish"
    ];
    files = [
      ".config/monitors.xml"
      ".config/gh/hosts.yml"
    ];
    allowOther = true;
  };
}
