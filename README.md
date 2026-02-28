# dotfiles

Personal NixOS configuration using flakes, featuring an impermanence-based setup with encrypted BTRFS filesystem.

## Features

- **Impermanence**: Root and home directories are wiped on every boot for enhanced security
- **Encryption**: Full disk encryption with LUKS, supporting Yubikey FIDO2 authentication
- **Secure Boot**: Implemented via lanzaboote
- **Declarative**: Everything managed through Nix flakes
- **Multi-host**: Support for desktops, laptops, and servers

## Quick Start

### Development Environment

```bash
# Clone the repository
git clone https://github.com/TGuimbert/dotfiles.git
cd dotfiles

# Enter the development shell (provides all necessary tools)
nix develop
```

## Installation

### Desktop/Laptop Installation

This process is for physical machines where you have direct access (leshen, griffin, tuxedo).

#### 1. Prepare the Installation

```bash
# Clone this repository
git clone https://github.com/TGuimbert/dotfiles.git
cd dotfiles

# Set your target hostname
export NEW_HOSTNAME=<hostname>  # e.g., griffin, leshen, tuxedo
```

#### 2. Format the Disk

**⚠️ Warning**: This will erase all data on the target disk!

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko ./hosts/$NEW_HOSTNAME/disks.nix
```

#### 3. Create User Password

```bash
sudo -s
mkpasswd -s > /mnt/persistent/tguimbert-password
exit
```

#### 4. Disable Secure Boot Temporarily

Edit the host configuration to use systemd-boot instead of lanzaboote for the initial install:

```bash
nano hosts/$NEW_HOSTNAME/default.nix
```

Comment out lanzaboote settings and ensure systemd-boot is enabled in the configuration.

#### 5. Install NixOS

```bash
sudo nixos-install --no-root-password --flake ./#$NEW_HOSTNAME
```

Reboot when complete.

#### 6. Post-Installation: Enable Secure Boot

After the first boot, set up Secure Boot:

```bash
# Verify boot status
bootctl status

# Enable secure boot in your configuration and rebuild
nh os switch

# Create secure boot keys
sudo sbctl create-keys

# Sign the keys by rebuilding
nh os switch

# Verify everything is signed (only bzImage.efi should be unsigned)
sudo sbctl verify

# Reboot and enable Secure Boot in BIOS
# Then enroll the keys
sudo sbctl enroll-keys --microsoft

# Reboot and verify
bootctl status
```

Don't forget to set a BIOS password!

### Server Installation (Remote)

For headless servers (e.g., srv-01), use nixos-anywhere for remote installation.

#### Option 1: Manual Installation

```bash
# Install directly to a remote host
nix run github:nix-community/nixos-anywhere -- \
  --flake .#srv-01 \
  --target-host root@10.0.0.108
```

Replace `10.0.0.108` with your server's IP address.

#### Option 2: Using Bootstrap Script (Recommended)

The repository includes a bootstrap script that automatically handles SSH key deployment:

```bash
# Edit the script with your server IP
nano scripts/bootstrap-srv-01.nu

# Run the bootstrap (requires Bitwarden CLI and nushell)
./scripts/bootstrap-srv-01.nu
```

The bootstrap script will:
1. Retrieve SSH host keys from Bitwarden
2. Deploy them during installation
3. Install NixOS using nixos-anywhere

## Post-Installation Setup

### Yubikey for LUKS Encryption (Desktop/Laptop)

Enhance security by using your Yubikey to unlock the encrypted partition:

#### 1. Backup LUKS Header

```bash
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 \
  --header-backup-file /run/media/tguimbert/<usb-key-name>/luks_backup.bin
```

#### 2. Enroll Yubikey

```bash
sudo systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto
```

#### 3. Create Recovery Key

```bash
sudo systemd-cryptenroll /dev/nvme0n1p2 --recovery-key
```

**Important**: Write down the recovery key and store it safely!

#### 4. Optional: Add Password

Note: The boot keyboard is in QWERTY layout.

```bash
sudo systemd-cryptenroll /dev/nvme0n1p2 --password
```

#### 5. Remove Old Key (Optional)

```bash
sudo systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=0
```

#### 6. Test All Keys!

Reboot and verify that all enrollment methods work before relying on them.

## Filesystem Layout

The system uses BTRFS with multiple subvolumes implementing different persistence levels:

| Subvolume    | Mount Point | Persistence | Purpose                          |
|--------------|-------------|-------------|----------------------------------|
| `root`       | `/`         | Ephemeral   | System root, wiped on reboot     |
| `nix`        | `/nix`      | Persistent  | Nix store                        |
| `persistent` | `/persistent` | Persistent | Stateful data                   |
| `log`        | `/var/log`  | Persistent  | System logs for debugging        |
| `home`       | `/home`     | Ephemeral   | User home, wiped on reboot       |
| `snapshot`   | `/.snapshot` | Persistent | Backup snapshots (15-30 days)   |
| `swap`       | `/.swapvol` | Persistent  | Swap file                        |

### Impermanence

The system implements "impermanence" where most of the filesystem is reset on each boot:

- **Root (`/`) and Home (`/home`)** are wiped clean on every reboot
- Only explicitly configured paths in `/persistent` survive reboots
- Snapshots are automatically created before each wipe
- Old snapshots are cleaned up after 15 days (root) or 30 days (home)

Benefits:
- No accumulation of cruft over time
- Better security (temporary files are truly temporary)
- Reproducible system state
- Forces explicit declaration of important data

## Common Operations

### Updating the System

The repository uses CI to automatically update flake inputs. To update your system:

```bash
# Navigate to your dotfiles
cd ~/.dotfiles

# Pull the latest changes (flake.lock is updated by CI)
git pull

# Rebuild and switch to the new configuration
nh os switch
```

**Note**: Flake updates are managed by CI (Renovate), so you typically don't need to run `nix flake update` manually.

### Managing Secrets

Secrets are managed with SOPS (uses age encryption):

```bash
# Edit secrets (auto-decrypts/encrypts)
sops secrets/common.yaml
sops secrets/srv-01.yaml
```

### Development Shells

```bash
# Enter a development environment
nix develop .#<shell-name>

# Available shells:
# - nixos, python, rust, go, ops, markdown, nodejs, protobuf
# - python-nodejs, python-protobuf (combined shells)
```

### Formatting Code

```bash
# Format all Nix files
nix fmt

# Lint Nix files
statix check
```

## Repository Structure

```
.
├── flake.nix           # Main flake configuration
├── hosts/              # Per-host configurations
│   ├── leshen/         # Desktop system
│   ├── griffin/        # Laptop (ThinkPad)
│   ├── tuxedo/         # Laptop (work)
│   └── srv-01/         # Server
├── home/               # Home Manager configurations
│   ├── default.nix     # Base user configuration
│   ├── shell.nix       # Shell environment (nushell, helix, zellij)
│   ├── dev.nix         # Development tools
│   └── desktop.nix     # Desktop applications
├── modules/nixos/      # NixOS modules
│   ├── core.nix        # Core system configuration
│   ├── impermanence.nix # Impermanence setup
│   ├── gnome.nix       # GNOME desktop
│   └── ...             # Other modules
├── shells/             # Development shell environments
├── secrets/            # SOPS encrypted secrets
└── scripts/            # Helper scripts
```

## Troubleshooting

### Boot Issues

If the system fails to boot after changes:
1. Select an older generation from the boot menu
2. Roll back: `sudo nixos-rebuild switch --rollback`

### Persistence Issues

If you need to persist a new directory or file:
- System-level: Add to `environment.persistence."/persistent"` in the host config
- User-level: Add to `home.persistence."/persistent"` in home configuration

### Recovery

If you lose access:
1. Boot from NixOS installer
2. Decrypt LUKS: `cryptsetup open /dev/nvme0n1p2 encrypted`
3. Mount BTRFS: `mount /dev/mapper/encrypted /mnt`
4. Access your data in `/mnt/persistent`

## License

Apache 2.0 - See LICENSE file for details
