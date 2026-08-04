# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a NixOS dotfiles repository using Nix flakes. It manages configurations for multiple hosts (desktop and server systems) using a modular architecture with Home Manager integration. The repository implements an ephemeral-root filesystem layout (via the preservation module) where `/` is a tmpfs (RAM-backed, wiped on every reboot) for enhanced security; only explicitly preserved paths survive.

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

### Deploying to srv-01

The server is never rebuilt in place from a checkout — it has none. Changes reach it two ways:

```bash
# Push: build on the workstation, copy the closure over SSH, activate
just deploy srv-01
just deploy-boot srv-01         # only set it as boot default
just deploy srv-01 10.0.0.57    # explicit ssh target

# Pull: run the nightly upgrade job now instead of waiting for the timer
just upgrade-now srv-01
just upgrade-log srv-01
```

Every remote recipe takes the same `<host> [target]` arguments, and `srv-01` is the default for
both. `<host>` is the `nixosConfigurations` name; `<target>` defaults to `<host>.local` — mDNS, because
srv-01's address is static and never registered by DHCP, so `srv-01.lan` does not resolve.
The avahi daemon that publishes it lives in `modules/server/base.nix` (deliberately not in the
`printing` aspect). `just --list` shows the rest (`check`, `fmt`, `build <host>`, `switch`,
`update`). `just` ships in the `nixos` dev shell. Flake refs only see git-tracked files, so
`git add` a new module before deploying.

### Updating the System

The repository uses CI (Renovate) to automatically update flake inputs: a weekly lockfile PR,
CI builds every host and pushes the closures to `tguimbert.cachix.org`, minor updates automerge on green.

Desktops pull and switch by hand:

```bash
# Navigate to the dotfiles directory
cd ~/.dotfiles

# Pull the latest changes (flake.lock is updated by CI)
git pull

# Rebuild and switch to the new configuration
nh os switch
```

srv-01 updates itself: the `autoUpgrade` aspect (`modules/auto-upgrade.nix`) pulls
`github:TGuimbert/dotfiles` nightly at ~03:00 and reboots only for a kernel change, only
between 03:00 and 05:00 (safe unattended because its LUKS volume unlocks from the TPM
against PCR 7). A run that fails — or one that stops happening — reaches Pushover through
Gatus; see "Monitoring srv-01".

**Note**: You typically don't need to run `nix flake update` manually since flake updates are managed by CI.

### Authentication on srv-01

Three ways in, because apps fall into three groups:

- **Forward-auth** (`modules/server/authelia.nix`) — for apps with no login of their own.
  `mkAutheliaRouter` (`modules/server/traefik-router.nix`) wraps a route in Traefik's
  `forwardAuth` middleware; Homepage, Calibre-web and the Traefik dashboard use it. Calibre-web
  additionally reads the `Remote-User` header Authelia sets, so that header contract is
  load-bearing — see `modules/server/calibre.nix`.
- **OIDC** — Authelia is also the OIDC provider (`identity_providers.oidc`), for apps that
  authenticate their own users. Clients are declared in that same file, with the client secret's
  pbkdf2 digest pulled from sops via `{{ secret "…" }}` rather than committed in cleartext.
  Discovery lives at `https://auth.<domain>/.well-known/openid-configuration`.
- **LDAP** (`modules/server/lldap.nix`) — for apps that speak neither. Kept **deliberately**: the
  Jellyfin OIDC plugin (`9p4/jellyfin-plugin-sso`) was archived upstream in May 2026 with no
  successor fork, and never completed the flow outside a browser anyway, so LDAP is the only
  credential its TV and mobile clients can use. That is now a live dependency rather than a
  hypothetical one — see "Media on srv-01". Nothing else off-host currently binds `:636`; do not
  remove LLDAP on that basis alone.

Passkeys are enabled (`webauthn.enable_passkey_login`). Authelia 4.39 counts a passkey as *one*
factor, so it opens the `one_factor` forward-auth routes on its own, but not an OIDC client set
to `two_factor` — that still wants a password plus TOTP or a security key.

Sessions are held in memory (no `session.redis`), so restarting Authelia logs everyone out. The
nightly upgrade restarts it whenever the package or config changes.

Adding an OIDC client: generate a secret with
`authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72`, put the
plaintext and the digest in `secrets/srv-01.yaml`, reference the digest from the client entry, and
hand the plaintext to the app. Authelia refuses to start with an empty client list.

### Backing up srv-01

srv-01 pushes nothing. The `backup` aspect (`modules/server/backup.nix`) stages the lldap,
authelia, *arr and Jellyfin state into `/var/backup/data` at 01:00, and the TrueNAS *pulls* it
over SFTP, so srv-01 holds no credential that reaches its own backups. The media is never in
scope — it lives on the NAS to begin with — and neither is Jellyfin's metadata cache, which is
artwork it re-fetches on demand. Retention is the NAS's periodic
snapshot task, not anything here, and `/var/lib/traefik` is deliberately out of scope —
`acme.json` holds the wildcard cert's private key, which Cloudflare DNS re-issues for free.
Restores are in README.md.

### Monitoring srv-01

Split across two machines *because* their lifecycles differ, not for convenience. A monitor
sharing a host with the thing it monitors is silent exactly when that host dies, so the piece
that watches srv-01 is the piece that does not run on it.

- **Gatus** (`modules/server/gatus.nix`) runs here and is the alert router: it polls every
  route this host and the NAS serve, asserts the wildcard cert's expiry **once** (every route
  shares it, so twelve checks would mean twelve notifications), and pings the NAS and the
  router at layer 3. Routes behind Authelia are checked with `Accept: text/html` and asserted
  to answer exactly 302: Authelia returns a bare 401 to a client that sends no `Accept` header
  (Go's default, so Gatus), and following the redirect would record the login page's 200 —
  green without ever touching the service. Config-as-code, so the monitor list is that file: nothing to
  preserve, nothing to stage in `backup.nix`, and a restore is a rebuild. Its sqlite store is
  deliberately *unpreserved* — it exists to survive a service restart, not a reboot.
- **Beszel** — only the agent is here (`modules/server/beszel.nix`). The hub is a Community-train
  catalog app on the TrueNAS, which upgrades by hand and does not reboot nightly, so it is the
  stabler host and it can report that srv-01 stopped answering. The agent dials *out* over a
  WebSocket, so nothing is opened and no route is exempted from the authelia middleware. No
  agent runs on the NAS: there is no catalog app for one, SMART and disk I/O are broken there,
  and Gatus already covers what matters.
- **Heartbeats.** `mkHeartbeat` (defined in `gatus.nix`, consumed by `backup.nix` and
  `auto-upgrade.nix`) attaches an `ExecStopPost` that pushes to a Gatus `external-endpoint`.
  One drop-in covers both failure modes: the job *failed* pushes `success=false` and alerts at
  once; the job *never ran* pushes nothing and the heartbeat interval expires. That is why
  those aspects now depend on `gatus` — importing one without it fails to evaluate, which is
  the loud failure rather than a job reporting nowhere.
- **The backstop.** Everything routes through Gatus so alerting is configured in one place,
  with one exception: `notify-pushover@.service` is wired to `gatus.service`'s `OnFailure`,
  because a dead alert router cannot announce itself.

Adding a monitor is a commit, not a click. Pushover credentials, the heartbeat bearer token
and the TrueNAS API key live in `gatusEnvironments` (sops), interpolated by Gatus as `${VAR}`
so none of them reach the store.

Two things deliberately stay outside this. **Pool and SMART health on the NAS** report through
TrueNAS's own Email alert service rather than Pushover, so Gatus checks only that the NAS's web
UI is serving — the half TrueNAS cannot report on itself, since a NAS that is down cannot email
you that it is down. Polling the rest would mean the REST API, which 25.04 deprecated, 26
removes, and which TrueNAS raises a daily alert for using at all; its WebSocket replacement
needs a login round trip before the query, which a Gatus websocket endpoint cannot do. And
**a whole-house power or ISP outage** silences both machines — closing that needs an outbound
heartbeat to something off-site.

### Media on srv-01

Three aspects, split along the lines that actually differ:

- **`mediaLibrary`** (`modules/server/media-library.nix`) — the storage, declared once and read by
  the other two. The bytes live on the NAS (`main/media/video`, sibling of the `books` dataset
  Calibre-web uses) and reach srv-01 over **NFS**, via a `_lib/nfs.nix` builder mirroring the CIFS
  one. NFS rather than CIFS because three services share the tree: CIFS fakes ownership with one
  mount identity for all of them, where NFS carries real uid/gid and does hardlinks and atomic
  renames — what the *arr do on every import, and what a downloader would need later.
- **`jellyfin`** (`modules/server/jellyfin.nix`) — transcoding runs here and not on the NAS
  *because of the silicon*: srv-01's i5-9500T has a UHD 630 that decodes HEVC 10-bit and tone-maps
  HDR→SDR in fixed-function hardware, against the NAS's Celeron J4125. VAAPI rather than QSV (on
  Gen9.5 the QSV path wants the legacy libmfx runtime for no gain), and `forceEncodingConfig`
  makes `encoding.xml` config-as-code — the dashboard's transcoding page is overwritten on every
  restart, deliberately.
- **`servarr`** (`modules/server/servarr.nix`) — Sonarr, Radarr and Prowlarr as one aspect
  driven by a table, since they differ only in name, port and tile. No downloader: imports are
  manual, so these organise and rename rather than fetch.

Two things are easy to get wrong here:

- **Jellyfin is the one route with no Authelia middleware** (`mkRouter`, not `mkAutheliaRouter`).
  A TV or phone client cannot complete a browser SSO round trip, so Jellyfin authenticates them
  itself against LLDAP — that is what LLDAP is *for*. The *arr, browser-only admin UIs, sit behind
  the middleware and delegate to it entirely (`auth.method = "External"`). Do not "harden" that
  back to `"Forms"`: these apps only offer the screen that creates their first user while no
  method is configured, so setting one before first run leaves a login page, an empty user table
  and no way in.
- **`UMask = "0002"` on Sonarr and Radarr is load-bearing**, and forced over the modules' 0022.
  The NAS dataset carries a POSIX default ACL granting the `media` group write, but a default
  ACL's effective permission is capped by the mask the creation mode implies: a directory created
  under 0022 lands group `r-x`, and the next writer — a manual copy over SMB from a desktop —
  cannot write into it. The `media` gid (3006) is **read back from the NAS**, not chosen — TrueNAS
  allocated it, and a number invented here would put the services in a group matching nothing. The
  export maps every request to `media:media`, so client *uids* never have to line up.

Prowlarr additionally runs with `DynamicUser` forced off, for the same reason lldap does: a uid
allocated per boot cannot own preserved state.

### Formatting and Linting

```bash
# Format the tree (nixfmt via treefmt; `just fmt` is the same thing)
nix fmt

# Format-check + lint + evaluate every host and shell
just check

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
- `leshen`: Desktop system with niri + noctalia, games, podman (`displaysLeshen` for its dual monitors)
- `griffin`: Lenovo ThinkPad T490 laptop with niri + noctalia, games, podman (`laptop` for lid handling)
- `srv-01`: Headless bare-metal server with Traefik, LLDAP, Authelia (forward-auth + OIDC provider), Homepage, Calibre-web, Jellyfin + the *arr over an NFS library from the NAS, and a Home Assistant OS libvirt guest bridged onto the LAN via `br0`; LUKS unlocked from the TPM (PCR 7). Backups are a TrueNAS pull, not a push — see "Backing up srv-01"; monitoring is split with the NAS — see "Monitoring srv-01"; the media stack is in "Media on srv-01"

### Module Organization

One feature = one capability file holding its NixOS **and** home-manager config together (organized by capability, not by module class). Features contribute to merge points:
- `nixos.modules.base` — every host (boot, locale, nix settings, disko, user account + nushell login shell, sshd, avahi, fwupd/smartd/btrfs-scrub, cli tools, preservation, sops)
- `nixos.modules.desktop` — desktop hosts (niri, noctalia, greeter, appearance, firefox, audio, NetworkManager + CIFS, tailscale, printing client, GUI home)
- `nixos.modules.server` — srv-01 baseline (`modules/server/`); deliberately thin — only the sops file, the headless service disables and static networking
- Named opt-in aspects imported only by hosts that want them: `secureBoot` (lanzaboote; every host with a bootloader), `autoUpgrade` (pull-based nightly updates; srv-01 only), `games`, `podman`, `displaysLeshen`, `laptop`, `docker` (no host currently imports it), and the srv-01 services (`traefik`, `authelia`, `lldap`, `homepage`, `backup`, `calibre`, `printing`, `homeAssistant`, `gatus`, `beszel`, `mediaLibrary`, `jellyfin`, `servarr`)

**Cross-aspect collectors.** A few things are contributed *by* a feature but assembled by
another. Rather than a central list that drifts, the assembling aspect declares a collector and
each feature adds to it beside its own config:

- `homepageTiles.<Group>` (declared in `modules/server/homepage.nix`) — a service's dashboard tile
  lives in that service's file. Keyed by group because `services.homepage-dashboard.services` is a
  *list* of groups and list definitions concatenate, so two files contributing to `Admin` directly
  would render two groups called Admin; attrsets merge by key instead. `homepage.nix` keeps the
  tiles for things that run off this host, the group order, and an assertion that no tile names a
  group outside it. Tiles are sorted by name within a group, since merge order follows module
  evaluation rather than intent.
- `mkRouter` / `mkAutheliaRouter` (`modules/server/traefik-router.nix`), `mkHeartbeat`
  (`modules/server/gatus.nix`) and `mediaLibrary` (`modules/server/media-library.nix`) are the
  same idea via `_module.args`: a builder or a constant defined once, read by each feature.

Both create a real dependency — an aspect using `homepageTiles`, `mkHeartbeat` or `mediaLibrary`
will not evaluate on a host that omits `homepage`, `gatus` or `mediaLibrary`. That is deliberate: a loud eval failure beats a tile
that renders nowhere or a job that reports to nothing.

Most features are flat `modules/<feature>.nix` files; directories appear only for a cohesive multi-file capability (`desktop/`) or a peer-set (`machines/`, `server/`, `shells/`). Per-user config goes through `homeManager.modules.base` (every host) / `homeManager.modules.gui` (desktop) inside the owning feature file — never `home-manager.users.*` directly (except the wiring in `users.nix`).

### Ephemeral-Root Strategy

**tmpfs root**: `/` is a tmpfs (`size=25%`, `mode=755`, defined in `modules/_hosts/*/disks.nix` as a `disko.devices.nodev."/"` entry). It is RAM-backed and therefore inherently ephemeral — there is no rollback/wipe service; it is simply empty on every boot. The persistent state lives on BTRFS subvolumes.

**BTRFS subvolumes** (defined in `modules/_hosts/*/disks.nix`):
- `/nix`: Persistent (Nix store)
- `/persistent`: Persistent data (`neededForBoot = true`)
- `/var/log` (`/log`): Persistent logs
- `/.swapvol` (`/swap`): Swap file (desktop hosts only)

**`/tmp`**: not a tmpfs — it is a preservation bind-mount from the `/persistent` subvolume (so nix builds and large temp writes hit disk, not the tmpfs root's RAM), with `boot.tmp.cleanOnBoot = true` wiping its contents each boot (`modules/boot.nix`).

**No rollback service**: because root is a tmpfs, there is no initrd rollback/wipe service and no pre-rollback snapshot retention (this replaced the earlier `btrfs-rollback.nix` subvolume-rename mechanism). The one tradeoff is the loss of that multi-day snapshot recovery net.

**Persistence**: Managed with the [preservation](https://github.com/nix-community/preservation) module (`modules/preservation.nix` imports it in `base` and enables it). State is declared via `preservation.preserveAt."/persistent"` blocks: `directories`/`files` for system state and `users.tguimbert.{directories,files}` for per-user state. Preservation is **NixOS-only** — there is no `home.persistence` home-manager option, so per-user paths are declared in the *NixOS* aspect of a feature file (`nixos.modules.base` for a feature every host has, `nixos.modules.desktop`/opt-in aspect otherwise), co-located with that feature's HM config. Bind-mounts are hidden with `commonMountOptions = [ "x-gvfs-hide" ]` (replaces impermanence's `hideMounts`).

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
- `nixos-hardware`: Hardware-specific configurations
- `nixvirt`: Declarative libvirt domains (srv-01's Home Assistant guest)

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

The default editor is Helix (`hx`), configured in `modules/helix.nix`. The editor and its `settings`
are on `homeManager.modules.base` (so srv-01 has them); the language tooling is on
`homeManager.modules.gui`, since a headless host would otherwise build `ltex-ls` to run nothing:
- Auto-formatting for Nix (nixfmt), Markdown (dprint), Go (goimports), YAML (prettier), Python (ruff)
- LSP support for various languages
- YAML schemas for GitHub Actions, Ansible, Kubernetes

## Shell Environment

Shared by every host, srv-01 included — SSH in and you get the same environment as a desktop.

- **Shell**: Nushell (nu) with carapace completions — also `tguimbert`'s **login shell**, so it is what
  an SSH session lands in. bash stays configured as a fallback (`ssh <host> -t bash -l`).
- **Multiplexer**: Zellij with custom keybindings
- **Terminal**: Foot (launches zellij on start) — desktop only
- **Prompt**: Starship with custom gruvbox-rainbow theme

Note: home-manager's nushell module does **not** read `home.sessionVariables`, so anything nu must see
goes in `programs.nushell.environmentVariables` (`modules/nushell.nix`). This matters more now that nu
is the login shell: over SSH there is no graphical session to have exported them.

## Important Notes

- User is `tguimbert` with UID 1000, immutable users (`mutableUsers = false`)
- Password stored at `/persistent/tguimbert-password` (hashed)
- SSH keys are yubikey-based (`sk-ssh-ed25519`)
- Secure Boot enabled via lanzaboote (`secureBoot` aspect; PKI bundle in `/var/lib/sbctl`, sbctl's own default)
- All hosts use LUKS encryption with systemd-cryptenroll support (FIDO2/password/recovery on the desktops, TPM 2.0 against PCR 7 on srv-01)
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

- `nixos.modules.base` — every host (nix settings, locale, boot, disko, user, sshd/avahi/fwupd/smartd, preservation, sops)
- `nixos.modules.desktop` — desktop hosts (niri, noctalia, greeter, appearance, firefox, audio, NetworkManager, tailscale); also pulls `home.gui`
- `nixos.modules.server` — srv-01 baseline
- Named opt-in aspects: `secureBoot`, `autoUpgrade`, `games`, `podman`, `displaysLeshen`, `laptop`, `docker`, `traefik`, `authelia`, `lldap`, `homepage`, `backup`, `calibre`, `printing`, `homeAssistant`, `gatus`, `beszel`, `mediaLibrary`, `jellyfin`, `servarr`

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

- `homeManager.modules.base` — merged into **every** host's `tguimbert`. Holds the shell environment,
  which srv-01 needs just as much as a desktop does: nushell (the login shell) + carapace, starship,
  zellij, helix, git, bat/eza/zoxide, jq/dig.
- `homeManager.modules.gui` — merged in **only on desktop** hosts (pulled by `nixos.modules.desktop`).
  Anything needing a screen, a browser or a yubikey: foot, firefox, noctalia theming, the ssh-agent +
  askpass, gpg, git commit signing, helix's language servers, gh, direnv, kubernetes, claude-code.
- Both are `deferredModule`s, so any number of feature files can set the same key and the values merge.
- `users.nix` imports `inputs.home-manager.nixosModules.home-manager` into `nixos.modules.base` and sets `home.stateVersion = osConfig.system.stateVersion` (the user's state version tracks the host's). The account itself is `modules/user.nix`.
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
│   ├── boot.nix  locale.nix  networking.nix  audio.nix  nix-settings.nix  services.nix  disko.nix  user.nix   # core features (flat)
│   ├── helix.nix  nushell.nix  zellij.nix  starship.nix  …   # shell tools (flat; or a shell/ dir if you prefer grouping)
│   ├── shells/                  # dev shells — peer-set dir (python.nix, rust.nix, …)
│   ├── desktop/                 # cohesive capability dir (niri, noctalia, greeter, appearance, firefox)
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
