# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a NixOS dotfiles repository using Nix flakes. It manages configurations for multiple hosts (desktop and server systems) using a modular architecture with Home Manager integration. The repository implements an ephemeral-root filesystem layout (via the preservation module) where `/` and `/home` are wiped on reboot for enhanced security.

## Common Commands

### Building and Switching Configurations

**Preferred: Use `nh` (NixOS Helper)**

```bash
# Build and activate configuration (automatically uses /home/tguimbert/.dotfiles)
nh os switch

# Test configuration without setting it as boot default
nh os test

# Just build without activating
nh os build
```

**Alternative: Direct nixos-rebuild commands**

```bash
# Build and activate for current host
sudo nixos-rebuild switch --flake .

# Build and activate for a specific host
sudo nixos-rebuild switch --flake .#<hostname>

# Test configuration without setting it as boot default
sudo nixos-rebuild test --flake .
```

### Updating the System

The repository uses CI (Renovate) to automatically update flake inputs. To update your system:

```bash
# Navigate to the dotfiles directory
cd ~/.dotfiles

# Pull the latest changes (flake.lock is updated by CI)
git pull

# Rebuild and switch to the new configuration
nh os switch
```

**Note**: You typically don't need to run `nix flake update` manually since flake updates are managed by CI.

### Formatting and Linting

```bash
# Format all Nix files
nix fmt

# Check for linter issues (uses statix)
statix check

# Auto-fix linter issues
statix fix
```

### Development Shells

The repository provides several development shells in `shells/`:

```bash
# Enter a development shell
nix develop .#<shell-name>

# Available shells:
nix develop .#nixos      # NixOS development tools
nix develop .#python     # Python (uses unstable)
nix develop .#rust       # Rust development
nix develop .#go         # Go development
nix develop .#ops        # Operations/DevOps tools
nix develop .#markdown   # Markdown tooling
nix develop .#nodejs     # Node.js development
nix develop .#protobuf   # Protocol Buffers

# Combined shells:
nix develop .#python-nodejs   # Python + Node.js
nix develop .#python-protobuf # Python + Protobuf
```

### Secrets Management (SOPS)

The repository uses SOPS for managing secrets with age encryption:

```bash
# Edit a secret file (auto-decrypts/encrypts)
sops secrets/common.yaml
sops secrets/srv-01.yaml

# Update all secrets after key rotation
find secrets -name "*.yaml" -exec sops updatekeys {} \;
```

Secret files are configured in `.sops.yaml` with per-host age keys.

### Initial Installation (New Host)

Follow the README.md installation instructions. Key steps:

1. Format disk with disko: `sudo nix run github:nix-community/disko -- --mode disko ./modules/_hosts/<hostname>/disks.nix`
2. Create user password: `sudo mkpasswd -s > /mnt/persistent/tguimbert-password`
3. Install: `sudo nixos-install --no-root-password --flake ./#<hostname>`
4. After reboot, setup secure boot with lanzaboote

## Architecture

The repo follows the **dendritic pattern** (see "Dendritic Pattern" below for the full mechanism). Every `.nix` file under `modules/` is a flake-parts module auto-loaded by a single `import-tree ./modules`; `_`-prefixed paths are skipped.

### Flake Structure

- **`flake.nix`**: Inputs only; `outputs = import ./outputs.nix`
- **`outputs.nix`**: flake-parts `mkFlake` running `import-tree ./modules`
- **Scaffolding** (flat in `modules/`): `nixos.nix` (merge points + central generation via `nixos.configurations.<host>`), `home-manager.nix`, `nixpkgs.nix` (nixpkgs config + overlays), `eval-modules.nix`, `users.nix` (user + home-manager wiring). No `mkSystem`/`mkServer`.

### Host Configurations

Each host is a thin import list in `modules/machines/<hostname>.nix` — it sets `nixos.configurations.<hostname>.module` to a list of feature aspects (`base`, `desktop`/`server`, opt-in aspects) plus its hardware/disks. Per-host `hardware.nix` and `disks.nix` live in `modules/_hosts/<hostname>/` (`_`-prefixed so import-tree skips them; referenced by relative path from the machine file).

**Current hosts**:
- `leshen`: Desktop system with GNOME, games, podman
- `griffin`: Lenovo ThinkPad T490 laptop with GNOME, games, podman
- `tuxedo`: Tuxedo InfinityBook laptop with GNOME, Docker, work config (scortex)
- `srv-01`: Headless server with Traefik, LLDAP, Authelia, Homepage, Restic

### Module Organization

One feature = one capability file holding its NixOS **and** home-manager config together (organized by capability, not by module class). Features contribute to merge points:
- `nixos.modules.base` — every host (boot, locale, networking, audio, nix settings, services, user, preservation, sops)
- `nixos.modules.desktop` — desktop hosts (gnome, stylix, lanzaboote, firefox, GUI home)
- `nixos.modules.server` — srv-01 baseline (`modules/server/`)
- Named opt-in aspects imported only by hosts that want them: `games`, `podman`, `docker`, `scortex`, and the srv-01 services (`traefik`, `authelia`, `lldap`, `homepage`, `restic`, `calibre`, `printing`)

Most features are flat `modules/<feature>.nix` files; directories appear only for a cohesive multi-file capability (`desktop/`) or a peer-set (`machines/`, `server/`, `shells/`). Per-user config goes through `homeManager.modules.base` (every host) / `homeManager.modules.gui` (desktop) inside the owning feature file — never `home-manager.users.*` directly (except the wiring in `users.nix`).

### Ephemeral-Root Strategy

**BTRFS subvolumes** (defined in `modules/_hosts/*/disks.nix`):
- `/root`: Ephemeral, rolled back on boot
- `/nix`: Persistent (Nix store)
- `/persistent`: Persistent data
- `/var/log` (`/log`): Persistent logs
- `/home`: Ephemeral, rolled back on boot
- `/.snapshot`: Stores pre-rollback snapshots (15 days for root, 30 for home)
- `/.swapvol` (`/swap`): Swap file

**Rollback mechanism**: Implemented in `modules/btrfs-rollback.nix` via systemd initrd service that moves old root/home to snapshots and creates fresh subvolumes (srv-01 has its own initrd wipe service in `modules/server/base.nix`).

**Persistence**: Managed with the [preservation](https://github.com/nix-community/preservation) module (`modules/preservation.nix` imports it in `base` and enables it). State is declared via `preservation.preserveAt."/persistent"` blocks: `directories`/`files` for system state and `users.tguimbert.{directories,files}` for per-user state. Preservation is **NixOS-only** — there is no `home.persistence` home-manager option, so per-user paths are declared in the *NixOS* aspect of a feature file (`nixos.modules.desktop`/opt-in aspect), co-located with that feature's HM config. Bind-mounts are hidden with `commonMountOptions = [ "x-gvfs-hide" ]` (replaces impermanence's `hideMounts`).

### Overlays

Defined in `modules/nixpkgs.nix` (`config.flake.overlays.default`): pulls specific packages from the unstable channel (helix, k9s, obsidian, orca-slicer, nushell, etc.)

### Key Dependencies

Major flake inputs:
- `nixpkgs`: NixOS 25.11 stable
- `unstable`: nixos-unstable for bleeding-edge packages
- `home-manager`: User environment management
- `disko`: Declarative disk partitioning
- `preservation`: Stateless system configuration (declarative state preservation)
- `lanzaboote`: Secure Boot support
- `sops-nix`: Secret management
- `stylix`: System-wide theming
- `nixos-hardware`: Hardware-specific configurations
- `tuxedo-nixos`: Tuxedo laptop support

## Development Workflow

### Adding a New Package

For system packages, add to the owning feature's `nixos.modules.*` block (or `modules/services.nix` / a host's machine file for host-specific needs).
For user packages, add to the owning feature's `homeManager.modules.*` block.
For unstable packages, add to the overlay in `modules/nixpkgs.nix` first.

### Adding a New Host

1. Create `modules/_hosts/<hostname>/` with `disks.nix`, `facter.json` (generate on the host with `sudo nix run nixpkgs#nixos-facter -- -o facter.json`) and a slim `hardware.nix` (`hardware.facter.reportPath = ./facter.json;` + host quirks facter can't detect)
2. Create age key for SOPS: `ssh-keyscan <hostname> | ssh-to-age`
3. Add host to `.sops.yaml`
4. Add `modules/machines/<hostname>.nix` defining `nixos.configurations.<hostname>.module` (import `base` + `desktop`/`server` + opt-in aspects, plus the host's `../_hosts/<hostname>/{hardware,disks}.nix`)
5. Add secrets file if needed: `secrets/<hostname>.yaml`

### Modifying Persistence

To persist new directories/files, add them to the owning feature's NixOS aspect:
- System-level: `preservation.preserveAt."/persistent".{directories,files}`
- User-level: `preservation.preserveAt."/persistent".users.tguimbert.{directories,files}` (paths relative to home). Declare this in the feature's `nixos.modules.*` block, **not** its `homeManager.modules.*` block — preservation is NixOS-only.

Entries are bare path strings, or `{ directory|file; user; group; mode; how; inInitrd; }` when a non-default owner/mode is needed (e.g. `.ssh`/`.gnupg` use `mode = "0700"`; ssh host keys use `how = "symlink"`). Remember: Only explicitly listed paths persist across reboots.

## Editor Configuration

The default editor is Helix (`hx`), configured in `modules/features/shell/helix.nix` with:
- Auto-formatting for Nix (nixfmt), Markdown (dprint), Go (goimports), YAML (prettier), Python (ruff)
- LSP support for various languages
- YAML schemas for GitHub Actions, Ansible, Kubernetes

## Shell Environment

- **Shell**: Nushell (nu) with carapace completions
- **Multiplexer**: Zellij with custom keybindings
- **Terminal**: Foot (launches zellij on start)
- **Prompt**: Starship with custom gruvbox-rainbow theme

## Important Notes

- User is `tguimbert` with UID 1000, immutable users (`mutableUsers = false`)
- Password stored at `/persistent/tguimbert-password` (hashed)
- SSH keys are yubikey-based (`sk-ssh-ed25519`)
- Secure Boot enabled via lanzaboote (PKI bundle in `/etc/secureboot`)
- All desktop hosts use LUKS encryption with systemd-cryptenroll support (FIDO2/password/recovery)
- Network shares auto-mount from `//nas.lan/` via CIFS with SOPS credentials
- Tailscale enabled on desktop systems for remote access

## Dendritic Pattern

This repository follows the **dendritic pattern** (mightyiam-aligned) using flake-parts and import-tree.

### Principles

- **Dendritic pattern**: Every `.nix` file (except scaffolding entry points) is a flake-parts module
- **import-tree**: One `import-tree ./modules` root; `_`-prefix a path to disable it
- **Imports as the toggle**: a host enables a feature by importing its aspect — **no `enable` options**
- **Feature closure**: one file holds a feature's NixOS + home-manager + package config; organize **by capability, not module class** (no `nixos/` or `home-manager/` directories)
- **Central generation**: `nixos.configurations.<host>` builds the systems — no `mkSystem`/`mkServer`, no `specialArgs`

### Module Mechanism (mightyiam bespoke options)

Scaffolding files live **flat in `modules/`** (`nixos.nix`, `home-manager.nix`, `nixpkgs.nix`, `eval-modules.nix`, `users.nix`) and are loaded by the **same `import-tree`** as every other module — they are ordinary flake-parts modules that happen to define the framework options. No `_dendritic/` subdir, no explicit import in `outputs.nix`. They define:

- `nixos.modules.<name>` — `lazyAttrsOf deferredModule`: named merge points / feature aspects
- `homeManager.modules.<name>` — same, for home-manager aspects
- `nixos.configurations.<host>` — submodule that evaluates `lib.nixosSystem`; feeds `flake.nixosConfigurations` + `flake.checks.configurations:nixos:<host>` (real toplevel builds in CI)
- `evalModulesModule` helper (`_module.args`) backing the above

**Merge points (system-types)** replace a separate profiles layer:

- `nixos.modules.base` — every host (nix settings, locale, networking, audio, services, boot, user, preservation, sops)
- `nixos.modules.desktop` — desktop hosts (gnome, stylix, lanzaboote, firefox, GUI home); also pulls `home.gui`
- `nixos.modules.server` — srv-01 baseline
- Named opt-in aspects: `games`, `podman`, `docker`, `scortex`, `traefik`, `authelia`, `lldap`, `homepage`, `restic`, `calibre`, `printing`

**Deliberate divergences from mightyiam/infra**: no `flake-file` (inputs stay hand-written in `flake.nix`); inputs stay real flakes (use `inputs.home-manager.nixosModules.home-manager`, not `flake = false`); single user `tguimbert` hardcoded (no multi-user `users` option machinery). Hardware detection uses nixpkgs' `hardware.facter` (report at `modules/_hosts/<host>/facter.json`, must be git-tracked); a slim `hardware.nix` per host keeps `facter.reportPath` + quirks facter can't detect.

### Home-manager wiring

Home-manager runs as a NixOS module, but feature files contribute HM config through the `homeManager.modules.*` merge points — *not* by touching `home-manager.users.*` directly. The flow:

```
feature file:  homeManager.modules.base = { … }   ─┐  (deferredModule; many files merge)
feature file:  homeManager.modules.gui  = { … }   ─┤
                                                   │   users.nix wires it:
nixos.modules.base    → home-manager.users.tguimbert.imports = [ homeManager.modules.base ]   (every host)
nixos.modules.desktop → home-manager.users.tguimbert.imports = [ homeManager.modules.gui ]    (desktop hosts only)
```

- `homeManager.modules.base` — merged into **every** host's `tguimbert`.
- `homeManager.modules.gui` — merged in **only on desktop** hosts (pulled by `nixos.modules.desktop`).
- Both are `deferredModule`s, so any number of feature files can set the same key and the values merge.
- `users.nix` imports `inputs.home-manager.nixosModules.home-manager` into `nixos.modules.base`, defines `users.users.tguimbert`, and sets `home.stateVersion = osConfig.system.stateVersion` (the user's state version tracks the host's).
- **Rule of thumb**: per-user config goes in a feature's `homeManager.modules.*` block (co-located with that feature's NixOS config); reserve direct `home-manager.users.tguimbert.*` for the wiring in `users.nix` only.

### Directory Structure

Flat by default (mightyiam-aligned). One feature = one flat `.nix` file; directories appear only for a cohesive multi-file capability or a set of homogeneous peers (see the rule below).

```
.dotfiles/
├── flake.nix                    # inputs only; outputs = import ./outputs.nix
├── outputs.nix                  # flake-parts mkFlake + import-tree ./modules
├── modules/                     # All modules auto-imported
│   ├── nixos.nix                # scaffolding (flat, loaded by import-tree)
│   ├── home-manager.nix         #   "
│   ├── nixpkgs.nix              #   "  (also holds overlays)
│   ├── eval-modules.nix         #   "
│   ├── users.nix                #   "
│   ├── formatter.nix            # flake-output feature (flat)
│   ├── boot.nix  locale.nix  networking.nix  audio.nix  nix-settings.nix  services.nix   # core features (flat)
│   ├── helix.nix  nushell.nix  zellij.nix  starship.nix  …   # shell tools (flat; or a shell/ dir if you prefer grouping)
│   ├── shells/                  # dev shells — peer-set dir (python.nix, rust.nix, …)
│   ├── desktop/                 # cohesive capability dir (gnome, stylix, firefox)
│   ├── server/                  # peer-set dir (traefik, authelia, lldap, …)
│   ├── machines/                # peer-set dir (leshen.nix, griffin.nix, … — thin import lists)
│   └── _hosts/                  # per-host hardware.nix + disks.nix (_-prefixed; skipped by import-tree)
└── secrets/                    # SOPS encrypted secrets
```

### When to create a directory (vs a flat file)

Because `import-tree` loads every file regardless of path, a path carries **no semantic meaning** — it is only a human label. Keep it shallow.

- **Default — one feature = one flat file** at `modules/<capability>.nix` (`boot.nix`, `firefox.nix`, `steam.nix`).
- **Directory case 1 — a cohesive capability that outgrew one file.** The dir *is* the feature; files inside are its parts (`desktop/`, `audio/`). You open the dir to work on that one thing.
- **Directory case 2 — a homogeneous set of peers.** Many files of the same kind (`machines/`, `shells/`, `server/`).
- **Soft domain grouping** is allowed when the dir names a real domain you'd browse together (e.g. `hardware/`) — not just "all the X-type modules."
- **Never a class/category bucket.** No `nixos/`, `home-manager/`, `darwin/` (that splits one feature across class dirs — the cardinal anti-pattern), and no generic `features/`/`flake/`/`programs/` umbrella. The test: does the dir name a real capability, domain, or peer-set, or merely a module *kind*?

### Feature Module Pattern

A feature file declares the relevant class block(s). **No `enable` options, no wrappers** — plain `pkgs.<tool>` + home-manager/NixOS config. One file = one capability (NixOS + HM together).

Always-on system feature → collector aspect on a merge point:
```nix
# modules/boot.nix
{ ... }:
{
  nixos.modules.base = { pkgs, ... }: {
    boot = { /* … */ };
    environment.systemPackages = [ pkgs.sbctl ];
  };
}
```

Per-user tool → home-manager aspect (merges into the shared home modules):
```nix
# modules/helix.nix
{ ... }:
{
  homeManager.modules.base = { pkgs, ... }: {
    home.packages = [ pkgs.helix ];
    programs.helix = { /* … */ };
  };
}
```

Opt-in feature → named aspect, imported only by hosts that want it:
```nix
# modules/steam.nix
{ ... }: { nixos.modules.games = { /* steam/gamemode config */ }; }
```

Host → thin import list:
```nix
# modules/machines/leshen.nix
{ config, inputs, ... }:
{
  nixos.configurations.leshen.module = {
    imports = (with config.nixos.modules; [ base desktop games podman ]) ++ [
      ./leshen/hardware.nix
      ./leshen/disks.nix
    ];
    system.stateVersion = "22.11";
  };
}
```

Key conventions:
- **Imports are the toggle** — no `options.features.*.enable`
- **Organize by capability, not class** — flat file per feature; directories only for a cohesive multi-file capability or a peer-set; never `nixos/`/`home-manager/`/`features/`/`flake/` buckets; co-locate a feature's NixOS + HM config in one file
- **`_`-prefix to disable** a file/dir from import-tree
- **No `specialArgs`** — `inputs` is already a module arg; use a `generic`-style constants module for cross-file sharing
- **`pkgs.stdenv.hostPlatform.system`** — not `pkgs.system` (deprecated)

### Dendritic rules & gotchas

The silent foot-guns — each wastes an afternoon if you hit it blind:

- **Never `lib.mkIf` in an `imports` list.** `imports` is evaluated unconditionally, so the condition is silently ignored and the module is *always* imported. Gate *config values* with `mkIf`/`mkMerge`; to make a feature conditional, control whether a host imports its aspect.
- **Never import across module classes.** A `nixos` aspect cannot import a `homeManager` aspect (different option sets → eval error). Cross-class sharing goes through the home-manager wiring above, or a generic/constants module.
- **No import cycles.** A imports B imports A → infinite recursion. Diamonds (A and C both import B) are fine.
- **Collector vs named aspect.** Always-on config merges into `nixos.modules.base` (a *collector*: many files set the same key and the values merge). Opt-in config gets its own `nixos.modules.<name>`, imported only by the hosts that want it.
- **`_`-prefix to disable.** A file or dir with `/_` in its path is skipped by import-tree — the dev toggle for a half-finished feature.
- **`inputs` by closure, not `specialArgs`.** Aspects reference `inputs.*` lexically (the file's `{ inputs, ... }:`); external NixOS modules (disko, lanzaboote, …) are imported *inside* the aspect that needs them, so hosts stay thin and no `specialArgs` is required.
- **`pipe-operators` must be enabled** or `|>` is a syntax error. It is enabled via `nix.settings.experimental-features`; the `flake.nix` `nixConfig` copy is *untrusted* and ignored unless you pass `--accept-flake-config` (or `--extra-experimental-features pipe-operators`).

### Sources

- [The dendritic pattern (mightyiam)](https://github.com/mightyiam/dendritic)
- [mightyiam/infra (reference implementation)](https://github.com/mightyiam/infra)
- [mattstruble nix-dendritic SKILL](https://github.com/mattstruble/skills/tree/main/nix-dendritic)
- [vic/import-tree](https://github.com/vic/import-tree)
- [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)
