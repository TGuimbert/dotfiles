# dotfiles

## NixOs installation

1. Clone this repo and move in it:
```shell
git clone https://github.com/TGuimbert/dotfiles.git
cd dotfiles
```
1. Run disko command to format the disk(s)
```shell
NEW_HOSTNAME=<hostname>
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./systems/x86_64-linux/$NEW_HOSTNAME/disks.nix
```
1. Add a password for the main user with:
```shell
sudo -s
mkpasswd -s > /mnt/persistent/tguimbert-password
exit
```
1. Disable lanzaboote setup and enable systemd boot:
```shell
nano systems/x86_64-linux/$NEW_HOSTNAME/default.nix
```
1. Install NixOS:
```shell
sudo nixos-install --no-root-password --flake ./#$NEW_HOSTNAME
```

**After the reboot**

1. Check that `UEFI` and `systemd-boot` are used and that `Secure Boot` is disabled:
```shell
bootctl status
```
1. Enable secure boot in the config and rebuild:
```shell
sudo nixos-rebuild switch --flake .
```
1. Create secure boot keys:
```shell
sudo sbctl create-keys
```
1. Sign the created keys by rebuilding:
```shell
sudo nixos-rebuild switch --flake .
```
1. Verify that everything is good (only bzImage.efi should not be signed):
```shell
sudo sbctl verify
```
1. Reboot and enable Secure Boot and its setup in the BIOS menu
1. Enroll the keys in the BIOS:
```shell
sudo sbctl enroll-keys --microsoft
```
1. Reboot
1. Check the everything is good:
```shell
bootctl status
```
1. Don't forget to put a password on the BIOS menu!

**Use Yubikey to unlock LUKS partition**

1. Backup LUKS header
```shell
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file /run/media/tguimbert/<usb-key-name>/luks_backup.bin
```
1. Enroll Yubikey
```shell
sudo systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto
```
1. Create a Recovery Key (don't forget to write it somewhere)
```shell
sudo systemd-cryptenroll /dev/nvme0n1p2 --recovery-key
```
1. Create a new password if needed (don't forget that the keyboard if in QWERTY during boot)
```shell
sudo systemd-cryptenroll /dev/nvme0n1p2 --password
```
1. Remove first key if needed
```shell
sudo systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=0
```
1. Test all the keys!

**Other setups**

1. Generate an SSH key and add it to Github:
```shell
ssh-keygen -t ed25519-sk -O verify-required
mv ~/.ssh/id_ed25519_sk.pub ~/.ssh/id_ed25519_sk.pub.hidden
cat ~/.ssh/id_ed25519_sk.pub.hidden
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
