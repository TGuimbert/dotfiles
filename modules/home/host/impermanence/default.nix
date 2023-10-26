{ inputs, ... }:
{
  imports = [ inputs.impermanence.nixosModules.home-manager.impermanence ];
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
      ".local/share/Anki2"
      ".local/share/direnv"
      {
        directory = ".local/share/keyrings";
        method = "symlink";
      }
      ".local/share/zoxide"
      ".minikube"
      ".mozilla"
      ".cache/tealdeer"
      ".cache/spotify"
      ".cache/pip"
      ".cache/pre-commit"
      ".config/obsidian"
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
