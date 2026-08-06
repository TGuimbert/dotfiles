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

This process is for physical machines where you have direct access (leshen, griffin).

#### 1. Prepare the Installation

```bash
# Clone this repository
git clone https://github.com/TGuimbert/dotfiles.git
cd dotfiles

# Set your target hostname
export NEW_HOSTNAME=<hostname>  # e.g., griffin, leshen
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

#### 4. Install Without Secure Boot First

lanzaboote cannot sign anything until `sbctl create-keys` has produced a PKI
bundle, which only exists once the machine is up. So install without it: drop
`secureBoot` from the host's import list in `modules/machines/<hostname>.nix`,
and add it back in step 6.

Imports are the toggle here — don't edit `modules/secure-boot.nix` to disable it.

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

The repository uses CI to automatically update flake inputs. Renovate opens a weekly
lockfile PR, CI builds every host and pushes the closures to `tguimbert.cachix.org`, and
minor updates automerge once the checks are green.

**Desktops (leshen, griffin)** — pull and switch by hand:

```bash
cd ~/.dotfiles
git pull            # flake.lock is updated by CI
nh os switch
```

**srv-01** — updates itself. `system.autoUpgrade` (`modules/auto-upgrade.nix`) pulls
`github:TGuimbert/dotfiles` nightly at ~03:00, substituting from cachix what CI already
built, and reboots only if the kernel changed and only between 03:00 and 05:00. There is
no alerting on failure, so if the host looks stale:

```bash
just upgrade-now srv-01     # run the timer's job now
just upgrade-log srv-01     # the last two nights' runs
```

**Note**: Flake updates are managed by CI (Renovate), so you typically don't need to run `nix flake update` manually.

### Deploying to srv-01

Your own changes are pushed from a desktop rather than waiting for the nightly pull —
the closure is built locally and copied over SSH:

```bash
just deploy srv-01              # build here, activate there
just deploy-boot srv-01         # only make it the boot default
just deploy srv-01 10.0.0.57    # same, with an explicit ssh target
```

The argument is the `nixosConfigurations` name; the ssh target defaults to `<host>.local`.
That is mDNS on purpose — srv-01 has a static address and never takes a DHCP lease, so the
router's `lan` zone never learns its name (`srv-01.lan` does not resolve, `srv-01.local`
does). `home.guimbert.fr` remains the namespace for *services*; mDNS names the *machine*.
Override the target as above if multicast is ever in the way (VLANs, AP isolation).

`just --list` shows the rest (`just check`, `just build <host>`, …). `just` comes from the
`nixos` dev shell, which direnv loads in this directory. Because flake refs only see
git-tracked files, `git add` any brand new module before deploying.

### Restoring srv-01

srv-01 never pushes a backup. A timer stages its service state into `/var/backup/data` at
01:00 — every sqlite database goes through the online-backup API, so they are consistent rather
than caught mid-write — and the TrueNAS pulls that over SFTP an hour later. History is the NAS's
snapshot schedule, so pick a snapshot there and copy its contents to the host first.

Then, on srv-01:

```bash
systemctl stop lldap authelia-main

rsync -a <pulled>/lldap/ /var/lib/lldap/
chown -R lldap:lldap /var/lib/lldap && chmod 0750 /var/lib/lldap
chmod 0400 /var/lib/lldap/server_key

rsync -a <pulled>/authelia-main/ /var/lib/authelia-main/
chown -R authelia-main:authelia-main /var/lib/authelia-main
chmod 0700 /var/lib/authelia-main

systemctl start lldap authelia-main
```

The media services restore the same way — indexers, quality profiles, libraries and watch history,
none of which is reproducible from a rebuild:

```bash
systemctl stop jellyfin sonarr radarr prowlarr bazarr seerr

for svc in jellyfin sonarr radarr prowlarr bazarr jellyseerr; do
  rsync -a <pulled>/$svc/ /var/lib/$svc/
  chown -R $svc:$svc /var/lib/$svc
done

systemctl start jellyfin sonarr radarr prowlarr bazarr seerr
```

The unit is `seerr.service` while its state lives in `/var/lib/jellyseerr` — nixpkgs renamed the
module, the directory predates the rename, and the loop above reflects both.

The books half restores differently, because Grimmory's state is not a directory. Its library
metadata, users and OIDC client are in MariaDB, and `/var/lib/grimmory` holds only covers and
reader state:

```bash
systemctl stop podman-grimmory shelfmark

runuser -u mysql -- mariadb < <pulled>/mysql/grimmory.sql

rsync -a <pulled>/grimmory/ /var/lib/grimmory/
chown -R grimmory:media /var/lib/grimmory && chmod 0750 /var/lib/grimmory

rsync -a <pulled>/shelfmark/ /var/lib/shelfmark/
chown -R shelfmark:shelfmark /var/lib/shelfmark && chmod 0700 /var/lib/shelfmark

systemctl start podman-grimmory shelfmark
```

The dump carries its own `CREATE DATABASE`, so it can be replayed into an empty MariaDB — which
is what a rebuilt host has, since `services.mysql` creates the database but nothing in it. Grimmory
migrates the schema forward on start, so a dump from an older tag restores into a newer one.
`runuser` is needed for the same reason it is in the backup job: MariaDB's superuser is the `mysql`
OS user, authenticated by which account opened the socket.

Paperless restores differently again, because it is the one service backed up by its own tooling.
What the NAS holds is a `document_exporter` tree — the originals, the archive PDFs and a manifest
carrying every tag, correspondent and date — rather than a copy of `/var/lib/paperless` and a
PostgreSQL dump:

```bash
systemctl stop paperless-{scheduler,web,consumer,task-queue}

rsync -a <pulled>/paperless/ /var/lib/paperless/export/
chown -R paperless:paperless /var/lib/paperless/export

systemctl start paperless-scheduler
paperless-manage document_importer /var/lib/paperless/export
```

`document_importer` refuses to run against an instance that already holds documents, so a rebuilt
host — where the migrations have run and nothing has been ingested — is exactly the right target.
The superuser comes back from sops on first start either way; the Authelia identity has to be
linked again from the user menu → My Profile → *Connect new social account*, since that link lives
in the database this replaces.

Jellyfin's artwork is deliberately not in the backup — it re-fetches it — so expect the libraries
to look bare until the first metadata scan finishes. Neither SABnzbd nor Recyclarr is in the
backup either: the first holds a re-downloadable queue, the second a clone of the TRaSH guides and
a config generated from the repo, so both rebuild themselves. The media itself was never at risk: it lives
on the NAS, and srv-01 only mounts it — books included, since they moved into the same export.

The staged copy is read by a single unprivileged account, so ownership is flattened on the way
out — hence the chown steps. Traefik is not in the backup and needs nothing: it re-issues the
wildcard certificate from Cloudflare DNS on first start.

Registered passkeys, TOTP enrolments and OIDC consent grants all live in the Authelia database
restored above, so they survive with it. Authelia's OIDC *issuer* key does not — it comes from
sops (`autheliaOidcIssuerPrivateKey`), so a host rebuilt from this repo keeps the same key and
existing OIDC clients need no reconfiguration.

### Bringing up monitoring

Gatus and the Beszel agent are declared in this repo, but the Beszel **hub** lives on the
TrueNAS — deliberately, so that whatever reports srv-01 being down is not itself on srv-01.
That makes the first run a bootstrap, since the agent cannot be configured before the hub
exists to mint its token:

1. **Pushover** — create an application; note its API token and your user key.
2. **TrueNAS** — Apps → Discover → install **Beszel Hub** from the Community train, and front
   it with the NAS's Traefik at `beszel.home.guimbert.fr`. Create the first user. Two
   requirements on that route, because the agent connects through it:
   - `beszel` must resolve to the NAS, not to srv-01.
   - It must **not** sit behind the authelia middleware. A forward-auth redirect on the agent's
     upgrade request to `/api/beszel/agent-connect` stops it connecting; put the whole route in
     the clear and rely on Beszel's own login. That also means you can still open the dashboard
     when srv-01 — and with it Authelia — is the thing that is down.
3. In the hub, add a system for srv-01 and copy the `KEY` and `TOKEN` it shows. Add a
   notification URL `pushover://shoutrrr:<api-token>@<user-key>/` and a **Status** alert on
   that system — this is the alert that fires when srv-01 stops reporting.
4. **TrueNAS** — System → Alert Settings, and point its **Email** alert service at your inbox.
   The split is: Gatus watches the NAS's web UI, because a NAS that is down cannot email you
   that it is down; everything it can report while running — pool degradation, SMART, scrub
   errors — goes by email and is the one signal that does not arrive on Pushover. Gatus does
   not poll those: the only HTTP route is the REST API, deprecated in 25.04, removed in 26, and
   alerted on daily by TrueNAS for merely being used.
5. `sops secrets/srv-01.yaml` and add:
   - `gatusEnvironments` — `PUSHOVER_TOKEN`, `PUSHOVER_USER_KEY`, and `GATUS_HEARTBEAT_TOKEN`
     (`openssl rand -hex 32`).
   - `beszelAgentEnvironment` — `TOKEN` and `KEY` from step 3.
6. `just deploy srv-01`, then check `journalctl -u beszel-agent | grep -i 'websocket connected'`
   and open `https://gatus.home.guimbert.fr`.

To add a check later, edit `modules/server/gatus.nix` and deploy — there is no UI to click,
which is the trade that keeps the monitor list in git and out of the backups.

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
# Format the tree (nixfmt via treefmt; `just fmt` is the same thing)
nix fmt

# Lint Nix files
statix check

# Format-check + lint + evaluate every host and shell
just check
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
│   ├── desktop/            # Desktop capability (niri, noctalia, greeter, appearance, firefox)
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
