# dotfiles

Personal NixOS configuration using flakes, featuring an ephemeral-root setup (via preservation) with encrypted BTRFS filesystem.

## Features

- **Impermanence**: Root is a tmpfs (RAM-backed), so the filesystem is empty on every boot for enhanced security; only explicitly preserved paths survive
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
  --mode disko ./modules/_hosts/$NEW_HOSTNAME/disks.nix
```

#### 3. Create User Password

```bash
sudo -s
mkpasswd -s > /mnt/persistent/tguimbert-password
exit
```

#### 4. Disable Secure Boot Temporarily

Edit the lanzaboote configuration to use systemd-boot instead for the initial install:

```bash
nano modules/lanzaboote.nix
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

The root filesystem (`/`) is a tmpfs (RAM-backed); persistent state lives on BTRFS subvolumes:

| Mount point   | Backing     | Persistence | Purpose                          |
|---------------|-------------|-------------|----------------------------------|
| `/`           | tmpfs (RAM) | Ephemeral   | System root, empty on every boot |
| `/tmp`        | preservation bind-mount | Cleaned on boot | Disk-backed temp (keeps builds off RAM) |
| `/nix`        | btrfs       | Persistent  | Nix store                        |
| `/persistent` | btrfs       | Persistent  | Stateful data                    |
| `/var/log`    | btrfs       | Persistent  | System logs for debugging        |
| `/.swapvol`   | btrfs       | Persistent  | Swap file (desktop hosts)        |

### Ephemeral root

The system implements an ephemeral-root layout (via the [preservation](https://github.com/nix-community/preservation) module) where the root is reset on each boot:

- **Root (`/`)** is a tmpfs, so it is empty on every boot — no wipe/rollback service is needed
- Only explicitly configured paths in `/persistent` survive reboots
- `/tmp` is disk-backed (a preservation bind-mount) and cleaned each boot via `boot.tmp.cleanOnBoot`

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
├── flake.nix               # Inputs only; outputs = import ./outputs.nix
├── outputs.nix             # flake-parts mkFlake + import-tree ./modules
├── modules/                # All modules auto-imported (dendritic pattern)
│   ├── nixos.nix           # Scaffolding: merge points + central generation
│   ├── home-manager.nix    # Scaffolding: homeManager.modules merge points
│   ├── nixpkgs.nix         # Scaffolding: nixpkgs config + overlays
│   ├── eval-modules.nix    # Scaffolding: evalModulesModule helper
│   ├── users.nix           # Scaffolding: user + home-manager wiring
│   ├── boot.nix …          # Flat feature files (one capability each)
│   ├── machines/           # Per-host thin import lists (leshen, griffin, …)
│   ├── _hosts/             # Per-host hardware.nix + disks.nix (skipped by import-tree)
│   ├── desktop/            # Desktop capability (gnome, stylix, firefox)
│   ├── server/             # Server services (traefik, authelia, lldap, …)
│   └── shells/             # Development shell environments
├── config/                 # Static config files (nushell, zellij, k9s)
└── secrets/                # SOPS encrypted secrets
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
