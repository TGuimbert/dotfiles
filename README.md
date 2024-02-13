# dotfiles

## NixOs installation

1. Clone this repo and move in it:
```shell
git clone https://github.com/TGuimbert/dotfiles.git
cd dotfiles
```
1. Run disko command to format the disk(s)
```shell
sudo nix --experimental-feature "nix-command flakes" run github:nix-community/disko -- --mode disko ./systems/x86_64-linux/<hostname>/disks.nix
```
1. Add a password for the main user with:
```shell
sudo -s
mkpasswd -s > /mnt/persistent/tguimbert-password
exit
```
1. Install secure boot keys:
```shell
nix-shell -p sbctl
sudo sbctl create-keys
sudo mv /etc/secureboot/ /mnt/etc/
exit
```
1. Install NixOS:
```shell
sudo nixos-install --no-root-password --flake ./#<hostname>
```

## Filesystem layout

The main idea on the filesystem are the following:

- The /boot is not encrypted
- The rest of the disk is encrypted with a single LUKS partition
- BTRFS is used
- Different subvolumes are used to differentiate the Impermanence lifecycles:
  - `root` is backed up and wiped at every reboot
  - `nix` is permanent to hold the Nix store
  - `persistent` is permanent to hold the stateful files
  - `log` is permanent to help debug things
  - `home` is backed up and wiped at every reboot
    - Separating it from `root` allows to have different backup lifecycles
  - `snapshot` is permanent to hold the `root` and `home` backups
  - `swap` is a swapfile
