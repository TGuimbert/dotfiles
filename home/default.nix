{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./dev.nix
    ./desktop.nix
  ];

  home = {
    username = "tguimbert";
    homeDirectory = "/home/tguimbert";
    stateVersion = "22.11";

    packages = with pkgs; [
      # CLI tools
      yubikey-manager
      rage
      age-plugin-yubikey
      sops
      bitwarden-cli
      bws
      jq
      dig
      dprint
      nixfmt-rfc-style
      asciinema

      # Desktop apps
      discord
      vlc
      remmina
      obsidian
      sweethome3d.application
      mullvad-browser
      signal-desktop
      orca-slicer
      freecad

      # K8s tools
      kubectl
      fluxcd
      kind
      kubectx
      minikube
    ];

    file.minikubeConfig = {
      target = ".minikube/config/config.json";
      text = builtins.toJSON {
        container-runtime = "containerd";
        rootless = true;
      };
    };

    # Persistence
    persistence."/persistent/home/tguimbert" = {
      directories = [
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "Workspace"
        ".dotfiles"
        ".config/discord"
        ".config/Signal"
        ".config/OrcaSlicer"
        ".config/FreeCAD"
        ".config/obsidian"
        ".gnupg"
        ".kube"
        ".local/share/direnv"
        ".local/share/keyrings"
        ".local/share/zoxide"
        ".minikube"
        ".mozilla"
        ".cache/tealdeer"
        ".cache/pip"
        ".cache/pre-commit"
        ".cache/FreeCAD"
        ".cache/uv"
        ".cache/orca-slicer"
        ".local/state/wireplumber"
        ".local/share/fish"
        ".local/share/FreeCAD"
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
        {
          directory = ".steam";
          method = "symlink";
        }
        ".clonehero"
        ".config/unity3d/srylain Inc_/Clone Hero"
      ];
      files = [
        ".config/monitors.xml"
        ".config/gh/hosts.yml"
        ".config/fish/conf.d/private.fish"
        ".docker/config.json"
        ".npmrc"
        ".pip/pip.conf"
        ".config/uv/uv.toml"
      ];
      allowOther = true;
    };
  };

  programs.home-manager.enable = true;

  stylix = {
    enable = true;
    targets = {
      starship.enable = true;
      firefox.profileNames = [ "default" ];
      qt.platform = "qtct";
      qt.enable = false;
    };
  };
}
