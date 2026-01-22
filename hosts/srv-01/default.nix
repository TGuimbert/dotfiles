{
  pkgs,
  lib,
  config,
  ...
}:
{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  nix.settings = {
    trusted-users = [
      "root"
      "tguimbert"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  sops = {
    defaultSopsFile = ../../secrets/srv-01.yaml;
    age.sshKeyPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ];
    secrets.hashed-password.neededForUsers = true;
  };

  services = {
    openssh = {
      enable = true;
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    qemuGuest.enable = true;
    xserver.enable = false;
    pipewire.enable = false;
  };

  environment.systemPackages = with pkgs; [
    htop
    iotop
    zellij
    helix
    curl
    wget
    git
  ];

  networking = {
    networkmanager.enable = false;
    useDHCP = true;
    firewall = {
      enable = true;
    };
  };

  users = {
    mutableUsers = false;
    users.tguimbert = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets.hashed-password.path;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA8ELMPZWIVpqfdLifNdzuMMEDdZFzqRKuExaFISizYrAAAAC3NzaDpob21lbGFi ssh:homelab"
      ];
    };
  };

  environment.persistence."/persistent" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  programs.fuse.userAllowOther = true;

  system.activationScripts.persistentHome.text = ''
    install -d -m 0755 -o root -g root /persistent/
    install -d -m 0755 -o root -g root /.snapshot/root/
  '';

  boot.initrd.postResumeCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/disk/by-partlabel/disk-main-root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';
}
