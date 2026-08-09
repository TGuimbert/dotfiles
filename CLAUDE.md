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
`printScan` aspect). `just --list` shows the rest (`check`, `fmt`, `build <host>`, `switch`,
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
  `forwardAuth` middleware; Homepage, Shelfmark, the *arr, the scanner UI and the Traefik
  dashboard use it.
  Shelfmark additionally reads the `Remote-User` header Authelia sets (`AUTH_METHOD = "proxy"`),
  so that header contract is load-bearing — it was Calibre-web's before, and moved intact to
  `modules/server/shelfmark.nix` when Calibre-web was removed.
- **OIDC** — Authelia is also the OIDC provider (`identity_providers.oidc`), for apps that
  authenticate their own users. Clients are declared in that same file (Immich, Grimmory,
  Paperless and Mealie), with the client secret's pbkdf2 digest pulled from sops via
  `{{ secret "…" }}` rather than committed in cleartext. Discovery lives at
  `https://auth.<domain>/.well-known/openid-configuration`.
  **The four clients differ from each other in ways that all fail misleadingly**, so none of them
  is a template for the next:
  - *Where the claims come from.* Immich and Paperless read **userinfo**; **Grimmory reads the ID
    token**, where Authelia puts only a standard subset. So Grimmory — and only Grimmory — needs a
    `claims_policies` entry naming `preferred_username`, `email`, `name` and `groups`; without it
    the login succeeds and the group mapping silently does nothing. Mealie reads the ID token
    **and falls back to userinfo** when a claim is missing, which is why it needs no policy despite
    mapping groups the way Grimmory does.
  - *How userinfo is signed.* Immich needs `userinfo_signed_response_alg = "RS256"`. Copying that
    line to **Paperless breaks login outright**: django-allauth calls `.json()` on the userinfo
    body, and a signed JWT is not JSON. Authelia's default of `none` is the correct one there, and
    for Mealie, whose fallback would meet the same JWT.
  - *Token endpoint auth.* Paperless states `client_secret_post` because allauth reads
    `token_endpoint_auth_methods_supported` from discovery and prefers it whenever advertised; a
    client left on basic auth 401s at the token exchange with nothing useful logged either side.
    Mealie is the one client that states `client_secret_basic`, because authlib picks that unless
    told otherwise — the same failure, mirrored.
  Paperless's redirect URI is derived from the `provider_id` in its sops-templated
  `PAPERLESS_SOCIALACCOUNT_PROVIDERS` (`/accounts/oidc/<provider_id>/login/callback/`), and
  Mealie's from its own `BASE_URL` plus `/login`, so in both cases two files have to agree byte for
  byte — a mismatch is reported only as an invalid redirect.
- **LDAP** (`modules/server/lldap.nix`) — for apps that speak neither. Kept **deliberately**: the
  Jellyfin OIDC plugin (`9p4/jellyfin-plugin-sso`) was archived upstream in May 2026 with no
  successor fork, and never completed the flow outside a browser anyway, so LDAP is the only
  credential its TV and mobile clients can use. That is now a live dependency rather than a
  hypothetical one — see "Media on srv-01" — and Radicale is a second one, for the same reason on
  different clients: CalDAV and CardDAV speak HTTP Basic, so DAVx5 and Thunderbird cannot complete
  a browser SSO round trip either (see "Calendars and contacts on srv-01"). Nothing else off-host
  currently binds `:636`; do not remove LLDAP on that basis alone.

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
authelia, *arr, Jellyfin, Shelfmark, Grimmory, Mealie and Radicale state into `/var/backup/data` at 01:00, and the
TrueNAS *pulls* it over SFTP, so srv-01 holds no credential that reaches its own backups. The
media is never in scope — it lives on the NAS to begin with — and neither is Jellyfin's metadata
cache, which is artwork it re-fetches on demand. Retention is the NAS's periodic
snapshot task, not anything here, and `/var/lib/traefik` is deliberately out of scope —
`acme.json` holds the wildcard cert's private key, which Cloudflare DNS re-issues for free.
Restores are in README.md.

Every database staged is sqlite through the online-backup API, **except Grimmory**, whose library
metadata, users and OIDC client are in MariaDB and go through `mariadb-dump --single-transaction`.
That dump is also the only backup of configuration this repo cannot rebuild — see "Books on
srv-01".

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

Seven aspects, split along the lines that actually differ:

- **`mediaLibrary`** (`modules/server/media-library.nix`) — the storage, declared once and read by
  everything else here. The bytes live on the NAS and reach srv-01 over **NFS**, via a
  `_lib/nfs.nix` builder mirroring the CIFS one. NFS rather than CIFS because many services share
  the tree: CIFS fakes ownership with one mount identity for all of them, where NFS carries real
  uid/gid and does hardlinks and atomic renames — what the *arr do on every import.
  **One dataset**, holding `movies/`, `shows/`, `downloads/` and `books/` as plain directories.
  It was two — `main/media/video` and `main/media/books` — which is a different thing entirely:
  ZFS makes each a separate filesystem, so `rename(2)` between them copies, and **NFSv4 does not
  cross a filesystem boundary without `crossmnt`**, which TrueNAS does not expose. Exporting
  their parent would show srv-01 two empty directories. Flattening is what makes one export
  serve the whole tree.
  Getting there meant promoting the video dataset to `main/media` and copying the books in, and
  three things on the NAS make that harder than it sounds — worth knowing before any similar
  surgery on this pool:
  - **The unmount a rename needs is blocked.** Six sandboxed systemd daemons (netdata, auditd,
    chronyd, udevd, logind, the TrueNAS audit handler) each hold a stale mount-namespace copy
    pinning the filesystem — invisible to `lsof`/`fuser`, and surviving a restart of all six,
    `zfs unmount -f` and `umount -f`; the shape of
    [openzfs#18334](https://github.com/openzfs/zfs/issues/18334). The way through is
    `zfs set canmount=noauto` on the datasets, reboot, rename while nothing is mounted, then set
    it back — and *check* it went back, or they silently do not mount at the next boot.
  - **ZFS refuses to move an encrypted child outside its encryption root.** The video dataset had
    to be made its own encryption root first, through the **TrueNAS UI** and not `zfs change-key`:
    TrueNAS keys its key database by *dataset name*, so a rename orphans the key and the dataset
    comes back locked at the next boot. Reverting the rename does not undo that; the way back is
    to unlock under the new name with an exported key JSON, which is why exporting keys before
    and after is mandatory rather than advisable.
  - **An unmounted mountpoint silently accepts writes** into whatever filesystem owns the
    directory, and TrueNAS then marks those directories immutable, so the stray data cannot even
    be deleted without `chattr -i`. `findmnt <path>` before writing anything under `/mnt/main`.
  The module also publishes `mediaLibrary.books.{library,bookdrop}` so the two aspects on either
  side of the BookDrop import cannot drift on where it is.
- **`jellyfin`** (`modules/server/jellyfin.nix`) — transcoding runs here and not on the NAS
  *because of the silicon*: srv-01's i5-9500T has a UHD 630 that decodes HEVC 10-bit and tone-maps
  HDR→SDR in fixed-function hardware, against the NAS's Celeron J4125. VAAPI rather than QSV (on
  Gen9.5 the QSV path wants the legacy libmfx runtime for no gain), and `forceEncodingConfig`
  makes `encoding.xml` config-as-code — the dashboard's transcoding page is overwritten on every
  restart, deliberately. The OpenCL half is **`intel-compute-runtime-legacy1`**, not
  `intel-compute-runtime`: Intel split NEO and the current package supports 12th Gen and newer,
  while this Gen9.5 GPU (PCI `0x3e92`) is in the legacy branch with Gen8/Gen11. Picking the wrong
  one looks like a missing driver rather than an unsupported GPU — the ICD installs, ffmpeg loads
  it, then enumerates nothing (`Failed to get number of OpenCL platforms: -1001`) and the
  HDR→SDR tone-map filter's `hwmap` dies with `No such device`. VAAPI keeps working throughout, so
  only HDR content fails.
- **`servarr`** (`modules/server/servarr.nix`) — Sonarr, Radarr and Prowlarr as one aspect
  driven by a table, since they differ only in name, port and tile.
- **`sabnzbd`** (`modules/server/sabnzbd.nix`) — the downloader the *arr hand releases to.
  Usenet only, so nothing seeds and nothing needs a hardlink to keep a file alive after import.
  Its two directories are split on purpose: **incomplete is local** (par2 repair and unrar rewrite
  the same bytes repeatedly, which belongs on the NVMe), **complete is inside the library export**
  (`/mnt/media/downloads`), so a finished file crosses the network once and the *arr import is a
  rename within one filesystem. A separate `downloads` dataset on the NAS would undo exactly that
  — a different dataset is a different filesystem, and `rename(2)` would fall back to a copy.

- **`bazarr`** (`modules/server/bazarr.nix`) — subtitles. It writes `.srt` *beside* each video
  rather than into a store of its own, so it needs the `media` group and `UMask = "0002"` exactly
  as the *arr do, and Jellyfin then finds the subtitles with no configuration. Its listen address
  is `general.ip` in its own config file, not a CLI flag, so unlike everything else here it cannot
  be bound to the loopback from Nix — the firewall is what keeps it off the LAN.
- **`recyclarr`** (`modules/server/recyclarr.nix`) — quality profiles as code, synced nightly from
  the TRaSH guides. Uses the **plain English** profiles rather than the `french-*` ones upstream
  also ships: they select from the widest pool of releases, which matters when a backbone can be
  missing most of a release's articles, and `bazarr` supplies French afterwards. 1080p and 2160p
  profiles are synced side by side. The **only media aspect with no preserved state and no backup
  entry** — its directory is a clone of the guides plus a config generated from the repo, so it
  rebuilds itself, which is also why its uid is left unpinned where every sibling has one.
  Two v8-specific traps, both of which fail misleadingly: **`include:` no longer exists** (the
  `config-templates` v8 branch ships `includes.json` as `{"radarr": [], "sonarr": []}` and replaced
  the fragments with whole starter configs, so an include dies with "Unable to find include
  template with name …" as though it were a typo — profiles are referenced by guide `trash_id`
  instead), and **instance names must be unique across both services**, not just within one, as
  must `base_url`s. Naming both instances `main` makes recyclarr log `Duplicate instances` at
  *debug* level, sync nothing, and **exit 0** — a green timer that never updates anything.
- **`jellyseerr`** (`modules/server/jellyseerr.nix`) — the request front end. nixpkgs renamed the
  module to **`services.seerr`** (it serves Plex and Emby too now), so the unit is `seerr.service`
  while the aspect, route, tile and state directory keep the Jellyseerr name.

Three things are easy to get wrong here:

- **Jellyfin, Jellyseerr and Grimmory are the three routes with no Authelia middleware**
  (`mkRouter`, not `mkAutheliaRouter`).
  A TV or phone client cannot complete a browser SSO round trip, so Jellyfin authenticates them
  itself against LLDAP — that is what LLDAP is *for*. Jellyseerr is exempt by extension: it
  authenticates against Jellyfin, so the household needs no Authelia account and no second login
  to request something from a phone. The *arr and Bazarr, browser-only admin UIs, sit behind
  the middleware and delegate to it entirely (`auth.method = "External"`). Do not "harden" that
  back to `"Forms"`: these apps only offer the screen that creates their first user while no
  method is configured, so setting one before first run leaves a login page, an empty user table
  and no way in.
- **SABnzbd's ini is generated but writable**, and its providers are in sops. `configFile = null`
  makes `modules/server/sabnzbd.nix` the source of truth; the module merges the existing file
  *under* the generated one, so every declared key wins on each activation and a UI edit to one
  survives only until the next deploy. `allowConfigWrite = true` is not laziness — SABnzbd tries
  to save its config every 30s, and against a read-only file each attempt logs `Cannot write to
  INI file`, which put 7000 lines into `sabnzbd.log` in under two hours and buried real errors.
  `misc.config_lock` does not help (only the web UI reads it; `save_config()` checks
  `is_writable()` unconditionally). The cost: a key *removed* from the Nix file is no longer
  removed from the ini, so deleting a server section means deleting `/var/lib/sabnzbd/sabnzbd.ini`
  on the host — safe, since it is regenerated. Both options key off `system.stateVersion` (25.11
  here), *not* the nixpkgs release, so below 26.05 they default the legacy mutable way and have to
  be stated. Section names (`[[unlimited]]`, `[[block]]`) are ids: SABnzbd keys servers by section
  name and connects using `host`, so every provider's hostname, username and password is a sops
  placeholder and nothing about the accounts reaches the store. **Two backbones, split by role** —
  the flat-rate `unlimited` at priority 0, the metered `block` at 1 with `required = false`, so
  the block is spent only on articles the first returns 430 for. One backbone is a single point of
  *availability*: a 430 is final, and a release arriving 82% missing is what a takedown looks like
  from the client side, not a misconfiguration. The api and nzb keys come from sops for a duller
  reason: SABnzbd invents them on first start and writes them back, so without them pinned a
  restore or a wiped ini would hand the *arr a key that no longer works.
- **`UMask = "0002"` on Sonarr, Radarr, SABnzbd, Bazarr, Shelfmark and Grimmory is load-bearing**,
  and forced over the *arr modules' 0022 and Shelfmark's 0077 (SABnzbd's and Bazarr's modules set
  none, so those are plain assignments; Grimmory's is podman's `--umask`).
  The NAS dataset carries a POSIX default ACL granting the `media` group write, but a default
  ACL's effective permission is capped by the mask the creation mode implies: a directory created
  under 0022 lands group `r-x`, and the next writer — the *arr moving a finished download out of
  it, or a manual copy over SMB from a desktop — cannot write into it. The `media` gid (3006) is **read back from the NAS**, not chosen — TrueNAS
  allocated it, and a number invented here would put the services in a group matching nothing. The
  export maps every request to `media:media`, so client *uids* never have to line up.

Prowlarr additionally runs with `DynamicUser` forced off, for the same reason lldap does: a uid
allocated per boot cannot own preserved state.

### Books on srv-01

Two aspects replacing Calibre-web, which is gone. The library moved into the media export (see
"Media on srv-01") because the point of the replacement is that **Grimmory owns the files** —
move, rename, delete, import — and CIFS could not carry the ownership to do it.

- **`grimmory`** (`modules/server/grimmory.nix`) — the library. It is **the only container on
  this host**, and the only aspect that is not built from source: Spring Boot on Java plus an
  Angular frontend, published as an image and requiring MariaDB, with no plausible nixpkgs path.
  What that costs is stated rather than hidden — the image tag is **pinned and never `latest`**
  (`autoUpgrade` rebuilds nightly, so a floating tag would make what runs here depend on when
  podman last pulled), and Renovate bumps it through a `customManagers` regex in
  `.github/renovate.json`, with automerge **off**: CI builds the closure but never starts the
  container, so nothing there can tell a working image from a broken one.
  - **Podman lives in this file**, not in `modules/podman.nix`. That aspect is workstation
    tooling — a minikube config via home-manager, `podman-compose`, and preservation of
    tguimbert's *rootless* image store. This runs rootful, so importing it would preserve a
    directory nothing writes and leave `/var/lib/containers` unpreserved — which on a tmpfs root
    means re-pulling the image into RAM every boot.
  - **`--network=host`**, so MariaDB stays on the loopback and Traefik reaches `:6060` there
    without a bridge, a published port or a second address for the database to listen on. The
    cost is that Grimmory binds 6060 on every interface; the firewall is what keeps it off the
    LAN, exactly as for Bazarr.
  - **`DISK_TYPE = "LOCAL"`.** `NETWORK` is upstream's guard for libraries on a mount that cannot
    rename, and it disables the UI's move, rename and delete — the operations this whole change
    exists to enable. It is safe here only because the library and the bookdrop are in one NFS
    filesystem.
  - **MariaDB is a NixOS service**, not a second container, so `/var/lib/mysql` is preserved and
    `backup.nix` can dump it. **`ensureUsers` is unusable**: it identifies users with
    `unix_socket`, which authenticates the *OS* user on the socket, and the container connects
    over TCP. A sops-templated `CREATE USER … / ALTER USER … / GRANT` runs on every boot instead
    — idempotent, and what makes a restore deterministic where `initialScript` (once, at database
    creation) would not be. The same fact bites in `backup.nix`: MariaDB's superuser is the
    **`mysql` OS user**, so the dump goes through `runuser`, not root.
  - **Not config-as-code, and this is the real break from every sibling.** Grimmory's OIDC client,
    its libraries and their organization mode live in MariaDB and are entered in its UI. Only a
    handful of env vars are declarative. The mitigation is that the database is in the backup.
    Two one-time settings are easy to miss: the Authelia issuer takes **no trailing slash**, and
    **BookDrop's periodic scan must be enabled in Settings → Tasks** — upstream states BookDrop
    does not reliably see new files on NFS, because network filesystems do not propagate inotify.
    Without it, Shelfmark's output sits in the bookdrop unnoticed.
- **`shelfmark`** (`modules/server/shelfmark.nix`) — search, request and download; what Readarr
  would have been. **In nixpkgs** (`services.shelfmark`), so it is an ordinary native aspect. It
  reuses this host's Prowlarr and SABnzbd rather than bringing its own, which makes it fail to
  evaluate without `servarr` and `sabnzbd` — the same deliberate loud failure as `mediaLibrary`.
  - Its API keys **cannot go in `services.shelfmark.environment`**: the module renders that into
    the unit's `Environment=`, which reaches the store and the journal. They come from a
    `sops.templates` file wired as `EnvironmentFile`, reusing the existing `prowlarrApiKey` and
    `sabnzbdApiKey` rather than making second copies.
  - **`PrivateUsers` is forced off**, and that is not hardening laziness. As `jellyfin.nix`
    already notes, a supplementary group outside the unit's uid map grants nothing — so
    membership of `media` would buy nothing and every write into the bookdrop would fail.
    `DynamicUser` is forced off for the usual preserved-state reason, and `ProtectSystem =
    "strict"` needs the bookdrop in `ReadWritePaths`.

The pipeline is SABnzbd's `books` category → `/mnt/media/downloads/books` → Shelfmark renames
into `books/bookdrop` → Grimmory imports into `books/library`. Only the last hop is a `rename(2)`:
Shelfmark's transfer method is **Copy**, because upstream is explicit that hardlinking into an
ingest folder is wrong — Grimmory then moves the file and the hardlink keeps the original alive.
For an epub that copy is nothing; the one dataset is still what makes the *arr side, and
Grimmory's own import, free.

### Documents on srv-01

Paperwork — bills, contracts, warranties — in `paperless` and `printScan`, which between them turn
the multifunction printer already attached to this host into an intake pipeline.

- **`paperless`** (`modules/server/paperless.nix`) — the archive. An **ordinary nixpkgs module**
  (`services.paperless`), which is the whole contrast with `grimmory`: no image tag to pin, no
  Renovate `customManagers` entry, and the weekly lockfile PR covers it.
  - **PostgreSQL, not the default sqlite** (`database.createLocally = true`). Four units — granian
    plus three celery processes — write concurrently, which is where sqlite starts returning
    `database is locked`. It is the second engine on this host after Grimmory's MariaDB; that costs
    nothing in `backup.nix`, because the exporter below makes the engine invisible there.
    `/var/lib/postgresql` is preserved as the **parent**, not `dataDir` — the latter carries the
    major version, so pinning it would silently land the next cluster on the tmpfs root.
  - **Backed up by its own tooling.** `services.paperless.exporter` runs `document_exporter` at
    00:30 into `/var/lib/paperless/export`, and `backup.nix` rsyncs *that* — not the media
    directory and not a database dump. The export is self-contained (originals, archive PDFs, a
    manifest carrying every piece of metadata) and restores with `document_importer`, which is
    upstream's supported path and engine-agnostic. It is the only entry in the backup staged this
    way. The exporter `Conflicts` the four paperless units while it runs, so there is a minute or
    two of nightly downtime — inside Gatus's 3-failure × 2-minute threshold, but that is why the
    two numbers are related.
  - **Local storage, deliberately.** `/var/lib/paperless` is on the NVMe rather than the NFS
    export, which keeps the module's `PrivateUsers = true` sandbox intact and — the real reason —
    keeps inotify consumption working. On a network filesystem it would not, the same fact that
    forces Grimmory's BookDrop into a polled scan.
  - **The consume directory is 0777** (`consumptionDirIsPublic`) *and* `scanservjs` is in the
    `paperless` group. It takes both, which is the trap: `dataDir` is preserved at **0750**, so a
    mode on the leaf is worth nothing without search permission on the way to it. Miss the group
    and the scanservjs action fails with `EACCES` on a directory `ls` shows as `drwxrwxrwx` — the
    permission that is missing is on the *parent*. The alternative, widening `dataDir` to 0755,
    was rejected: document *files* are 0600 under the module's `UMask = 0066`, but the filenames
    under `media/` would become listable by every local account.
    Note the group is on **scanservjs**, whose unit sets no `PrivateUsers` — the trick
    `jellyfin.nix` warns about (a supplementary group outside the unit's uid map granting nothing)
    would apply if this were on one of paperless's own units, and it is not.
  - **The password login stays enabled.** `PAPERLESS_DISABLE_REGULAR_LOGIN` and
    `PAPERLESS_REDIRECT_LOGIN_TO_SSO` are both left off on purpose: it is the way in when Authelia
    is the thing that is down (the argument README.md makes for keeping the Beszel hub off this
    host), and `/accounts/login/` rendering a 200 is what makes the Gatus check meaningful —
    `/api/status/` needs a staff session. Bootstrapping is: `passwordFile` creates the superuser
    named `PAPERLESS_ADMIN_USER`, you log in with it, and you **link** the Authelia identity from
    the user menu → **My Profile** → *Connect new social account* — not from Settings, which has
    no such page. allauth deliberately does not auto-link by email, and
    `PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = false` stops any other Authelia user
    self-provisioning. Note that paperless's `urls.py` includes only allauth's provider,
    signup and error routes — **not** `socialaccount_connections` — so the linking flow really is
    that dialog (backed by `/api/profile/social_account_providers/`, whose login URLs carry
    `process=connect`) and there is no `/accounts/3rdparty/` page to fall back to.
- **`printScan`** (`modules/server/print-scan.nix`) — the Samsung M2070 on the USB port, **both
  halves**. This was `printing`; it was renamed rather than split because one device on one cable
  with one proprietary driver derivation is one capability. `samsung-unified-linux-driver_1_00_37`
  was already loaded as a CUPS driver and *also* ships `libsane-smfp`, its `dll.d` entry and its
  udev rules, so the scanner half costs no new package — only `hardware.sane.extraBackends` and
  `services.scanservjs`. Note that CUPS and SANE contend for the same USB interface: an in-flight
  print job can make `scanimage -L` find nothing.
  - **`ippeveprinter` is driven by `-a printerAttrs`, not `-M`/`-m`/`-f`, and that is about paper
    size.** In its legacy mode — the one those three flags select — the media list is hardcoded and
    `media-default` is always `na_letter_8.5x11in`; no flag changes it, so a phone rasterised at
    Letter geometry however much `lp -o media=A4` was passed afterwards. Only `-a` (or `-P`) can
    override it, and ippeveprinter **refuses to combine either with `-M`, `-m` or `-f`**, so the
    whole capability set had to move into the file. It was captured from a live instance running
    the old flags (`ipptool … get-printer-attributes`) and edited, not invented.
    The cost is `application/pdf` and `image/jpeg` leaving `document-format-supported`:
    `create_printer()` builds that from the `-f` list unconditionally with no `ippFindAttribute`
    guard, so declaring it in the file emits a *duplicate* attribute rather than replacing it.
    Acceptable because every client here is Android and Mopria sends PWG Raster or URF. Verify
    changes with `ipptool -tv … ipp-everywhere.test` against a local `ippeveprinter -a` before
    deploying — that is how the two remaining conformance gaps were shown to be pre-existing
    (`overrides-supported`, a CUPS quirk) or accepted (`image/jpeg`).
  - **GrapheneOS phones need Mopria Print Service**; AOSP's built-in `com.android.bips` reports the
    printer as "blocked / waiting to send" against this proxy even though it discovers it and shows
    A4 correctly. Not a printer-description problem: a stock Android phone on Mopria prints the same
    attributes fine, and the same GrapheneOS handset works once Mopria replaces the built-in
    service. `printer-supply`/`printer-input-tray` levels are the tempting suspect — bips maps them
    onto `BLOCKED_REASON_OUT_OF_PAPER`/`OUT_OF_TONER` — but the block survives setting them to
    upstream's invented values, so they stay at `-2` ("unknown"), which is the truth for a proxy.

**A scan is not automatically a document, and that is the design.** Pointing scanservjs's
`outputDirectory` at the consume directory would file everything — a photo, a drawing, a page
scanned to email someone. Instead its output directory is an **inbox**, and `paperless.nix`
contributes a *Send to Paperless* action to the scanservjs UI. Two consequences worth knowing:

- The dependency runs the way the aspect layout wants it. `print-scan.nix` knows nothing about
  Paperless; `paperless.nix` appends to `services.scanservjs.extraActions`, an upstream **list**
  option, so definitions concatenate across modules — the same collector idiom as `homepageTiles`,
  on an option nixpkgs already provides. On a host with `paperless` and no scanner the action is
  simply never rendered, so unlike `mediaLibrary` or `mkHeartbeat` this one wants no loud failure.
- That action uses `require('fs').copyFileSync`, **not** scanservjs's own `Process` helper: the
  nixpkgs module renders `config.local.js` into the store, where upstream's
  `require.resolve('./server/classes/process', { paths: ['/usr/lib/scanservjs'] })` resolves
  nothing. Node builtins resolve from anywhere. A copy and not a move, so the scan survives in the
  inbox and filing the wrong page costs nothing.

`/var/lib/scanservjs` is therefore **preserved but not backed up** — an inbox, not an archive.
Anything worth keeping is either sent to Paperless, which is in the backup, or downloaded; a
scanned photo belongs in Immich on the NAS. Preserving it is also why `scanservjs`'s uid is pinned
where `recyclarr`'s is not.

### Recipes on srv-01

`mealie` (`modules/server/mealie.nix`) — recipes and meal planning. Another **ordinary nixpkgs
module** (`services.mealie`), so the `paperless` shape rather than the `grimmory` one: no image tag
to pin, no Renovate `customManagers` entry, the weekly lockfile PR covers it. Four things are
easy to get wrong:

- **SQLite, not the PostgreSQL the module can bring up.** `database.createLocally = true` would
  reuse the cluster `paperless` starts, but `/var/lib/postgresql` is preserved *in
  `paperless.nix`*, so `mealie` would silently depend on that aspect being imported — the opposite
  of the loud eval failure `mediaLibrary` and `mkHeartbeat` are built for. As one file at
  `/var/lib/mealie/mealie.db` it instead falls into `backup.nix`'s existing online-backup loop
  beside every other sqlite service here.
- **`settings` is rendered into `Environment=`,** which reaches the store *and* the journal, so the
  OIDC client secret goes through the module's `credentialsFile` from a sops template — the same
  split `shelfmark.nix` makes for its API keys. Note also that the module passes every `settings`
  value through `toString`, and Nix's `toString false` is the **empty string**: booleans have to be
  written `"true"`/`"false"` or they are silently unset.
- **`DynamicUser` is forced off** and uid/gid 360 pinned, for the reason `lldap.nix` gives — a uid
  allocated per boot cannot own preserved state, and it moves the state out of
  `/var/lib/private/mealie`. What is preserved is the database, the recipe images, and the app
  secret Mealie generates on first start and signs its tokens with.
- **The seeded first user is `changeme@example.com` / `MyPassword`, and cannot be configured
  away.** The env vars behind it are `_DEFAULT_EMAIL`/`_DEFAULT_PASSWORD` — pydantic *private*
  attributes, which upstream documents as no longer settable by end users. Deleting that account
  once the first Authelia login has created a real admin is a mandatory bootstrap step, not
  hygiene; the route carries no Authelia middleware. See README.md, "Bringing up Mealie".

The route is `mkRouter`, not `mkAutheliaRouter`, joining Jellyfin, Jellyseerr, Grimmory and
Paperless: Mealie has no proxy-header auth mode to delegate to the way the *arr do, and its REST
API is a client a browser SSO round trip cannot serve. Access is gated instead on the LLDAP groups
`mealie-users`/`mealie-admins` via `OIDC_USER_GROUP`/`OIDC_ADMIN_GROUP` — and setting either is
*also* what makes Mealie ask Authelia for the `groups` scope at all, so dropping them would quietly
take the claim with them. `OIDC_AUTO_REDIRECT` stays off for Paperless's reason: the local login is
the way in when Authelia is the thing that is down.

### Calendars and contacts on srv-01

`radicale` (`modules/server/radicale.nix`) — CalDAV and CardDAV. The `paperless`/`mealie` shape
again (`services.radicale`, an ordinary nixpkgs module), and the only aspect here whose backup
needs no dump of any kind: collections are plain `.ics`/`.vcf` files written by atomic rename, so
`backup.nix` stages `/var/lib/radicale` with the same rsync as everything else.

**It authenticates against LLDAP, and that is the second live reason LLDAP stays.** CalDAV and
CardDAV clients send HTTP Basic; DAVx5 and Thunderbird can no more complete a browser SSO round
trip than a TV can, so `auth.type = "ldap"` and the route is `mkRouter` — joining Jellyfin,
Jellyseerr, Grimmory, Paperless and Mealie. Access is gated on the LLDAP group `radicale-users`
through a `memberOf` clause in `ldap_filter`, the way Mealie gates on `mealie-users`. Bootstrap
(the group, and the read-only bind account LLDAP requires because it refuses anonymous search) is
in README.md, "Bringing up Radicale".

Four things fail misleadingly:

- **`server.hosts` is deliberately not set.** nixpkgs derives `bindLocalhost` from that key being
  *absent* and keys `IPAddressAllow = "localhost"` / `IPAddressDeny = "any"` off it, so declaring
  it — even to restate the default — silently drops the filter and buys back only a systemd block
  restoring it. The `port` in the `let` therefore *matches* Radicale's default rather than
  asserting it; it exists for `mkRouter`, and the comment on it says so.
- **`ldap_base` must be `ou=people,…`, not the root DN.** LLDAP evaluates `memberOf` as a *person*
  attribute; a search based anywhere else logs `Ignoring unknown group attribute "memberof" in
  filter`, matches nothing, and surfaces only as "no unique DN found" and a 401 for every user. The
  filter value must also be the group's full DN, not `cn=radicale-users` alone. `ldap_filter` is
  `str.format`ted for `{0}`, so any other brace in it raises at login time.
- **`ldap_user_attribute = "uid"` pins the collection path.** It is what Radicale uses as the login
  once the bind succeeds, and `rights.type = "owner_only"` derives `/<user>/` from that. Without
  it the path is whatever the client typed, so a differently-cased login silently gets a second,
  empty tree.
- **`auth.type` is not optional.** Radicale 3.5.0 changed its default from `none` to `denyall`, and
  the nixpkgs module asserts the key is set rather than letting a host come up refusing everyone.

`cache_logins` is on because Radicale otherwise binds to LDAP *twice per request* and DAV clients
poll; the expiry defaults (15s success, 90s failure) are left alone so removing someone from the
group still takes effect in seconds.

**The Gatus check is a `PROPFIND`, and a GET cannot replace it.** `GET /` 302s to `/.web` — the
login UI, which Radicale serves *unauthenticated* — so a GET check follows the redirect and records
that page's 200 without ever touching auth or a collection, the same trap `mkAutheliaHttps` avoids
by refusing its redirect. PROPFIND is what the DAV clients actually issue and what `owner_only`
refuses to an empty user, so asserting **401** on it says Radicale is serving *and* enforcing,
where a 200 or a 207 would mean auth had fallen away. (`/.web` being public is a login form, not an
exposure: no collection is readable without credentials.)

The uid is pinned (361) for `lldap.nix`'s reason — nixpkgs has allocated radicale's
dynamically since 2021 — and the sops secret is reached by `owner` rather than a supplementary
group, because the module's unit runs with `PrivateUsers`.

### Obsidian sync on srv-01

`couchdb` (`modules/server/couchdb.nix`) — the remote database the Obsidian **Self-hosted
LiveSync** plugin replicates a vault through. The `paperless`/`mealie`/`radicale` shape
(`services.couchdb`, an ordinary nixpkgs module), and `mkRouter` rather than `mkAutheliaRouter`,
joining Jellyfin, Jellyseerr, Grimmory, Paperless, Mealie and Radicale: a phone's webview cannot
complete a browser SSO round trip, and replication is a REST client besides.

**It is the one service here that cannot delegate its auth anywhere.** CouchDB speaks no LDAP, so
LLDAP is not an option the way it is for Radicale, and the credential is local to CouchDB. What
that is made to cost as little as possible: sops holds a **server admin** (`couchdb-admin`), used
only to bootstrap and to maintain, and the account the plugin carries is a **non-admin `_users`
account** granted `member` on the vault's database through an `obsidian-livesync` *role* — created
by hand, since neither it nor the database can come from Nix (README.md, "Bringing up CouchDB").
Granting by role rather than by name is what keeps a second vault from needing the `_security` doc
edited; `members` with both `names` and `roles` empty would open the database to every
authenticated user, so the role is load-bearing, not decoration. One account per **vault**, not per
device — every device on a vault targets the same database, so per-device accounts would be members
of the same database with identical rights.

The plugin tolerates that, but two of its flows do not, and both fail as a bare 403:

- **"Check and fix CouchDB issues"** reads `/_node/_local/_config`, which is server-admin only
  (upstream issue #988). That is *wanted* here: the "fix" button writes `local.ini`, which outranks
  the generated config — see below.
- **"Rebuild everything" / reset-remote** does `DELETE` then `PUT` on the bare database name, which
  `chttpd_auth_request.erl` gates on server admin. Paste the admin credential in for that one
  operation.

Routine compaction needs neither: smoosh's `db_channels` default compacts on its own.

Four things fail misleadingly:

- **The generated config is writable, the `sabnzbd.nix` situation.** The module passes
  `-couch_ini default.ini <store ini> <the sops one> /var/lib/couchdb/local.ini`, and CouchDB
  persists every runtime change to the **last** of those. So a Fauxton edit outranks the Nix file
  from then on, and a key *removed* from Nix is not removed from `local.ini`. Deleting
  `/var/lib/couchdb/local.ini` is the escape hatch; it is regenerated. The same fact makes
  **rotating `couchdbAdminPassword` in sops a no-op on its own**: CouchDB hashes the cleartext into
  `local.ini` on first start, and the merged view then shows only the hash. Rotation is edit sops,
  delete `local.ini`, restart.
- **`require_valid_user` and `require_valid_user_except_for_up` are both set.** Neither implies the
  other: `chttpd_auth.erl` gates every other path on `RequireValidUser orelse
  RequireValidUserExceptUp` and `/_up` on `RequireValidUser andalso not RequireValidUserExceptUp`.
  Dropping the second closes `/_up` and the Gatus check goes permanently red; dropping the first
  changes nothing, because the second already covers it.
- **CORS survives `require_valid_user` only because of ordering.** `chttpd.erl` answers the
  preflight *before* authenticating, so the credential-less `OPTIONS` a webview sends is not met
  with a 401. That is why no Traefik CORS middleware is wired in front of this route — a second
  `Access-Control-Allow-Origin` would make the browser reject the response outright.
- **The plugin's remote URI must be `https://`, and getting that wrong looks exactly like a CORS
  misconfiguration.** Traefik's `web` entrypoint 308-redirects to `websecure`, and the CORS spec
  forbids following a redirect on a *preflight* — so a `http://` URI is killed by the browser with
  `Redirect is not allowed for a preflight request` before CouchDB is ever reached, while
  Obsidian's `requestUrl` API follows the redirect happily. That is what produces the plugin's
  "the request was successful by API. But the native fetch API failed! Please check CORS settings"
  warning, and no amount of `[cors]` tuning fixes it. This applies to every route on this host, but
  only here does a client speak CORS. Check the scheme in the console error *first*; the origin and
  header theories are much more expensive to chase.
- **Four keys upstream's provisioning script sets are deliberately absent**, each checked against
  couchdb 3.5.1's source: `chttpd.max_http_request_size` is already the code default;
  `chttpd_auth.require_valid_user` is never read (both call sites go through
  `get_chttpd_config_boolean`, which is `[chttpd]` falling back to `[httpd]`);
  `httpd.WWW-Authenticate` only changes the realm string, which `require_valid_user` already emits;
  and `cors.headers`/`cors.methods` left unset yield `chttpd_cors.erl`'s built-in lists, which
  cover everything the plugin sends — pouchdb sets only `Accept`, `Authorization` and
  `Content-Type`. Stating either **replaces** the built-in list rather than extending it, so the
  short list the older upstream docs give would *narrow* it and drop `content-length`,
  `destination`, `if-match` and `x-couch-full-commit`. That matters if a custom header is ever
  configured in the plugin: it has to be added, and the value then has to be the whole built-in
  list plus that header. CouchDB does not **reject** a preflight naming a header outside the list —
  it declines to handle the preflight at all, falls through to the normal request path, and
  `require_valid_user` answers 401 with no `Access-Control-Allow-Headers`, so one unknown header
  poisons the whole preflight.

`backup.nix` stages `/var/lib/couchdb` with a plain rsync and no dump of any kind: the file format
is append-only, so upstream's own backup docs bless a copy taken while CouchDB is serving, and the
one ordering rule they give — secondary indexes before the databases — falls out of rsync's sorted
walk, since `.shards/` precedes `shards/`. The uid is *not* pinned, unlike every sibling here:
nixpkgs gives couchdb a static id (106).

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
- `srv-01`: Headless bare-metal server with Traefik, LLDAP, Authelia (forward-auth + OIDC provider), Homepage, Jellyfin + the *arr + SABnzbd + Grimmory + Shelfmark over one NFS library from the NAS, Paperless-ngx fed by the multifunction printer's scanner, Mealie, Radicale, CouchDB, and a Home Assistant OS libvirt guest bridged onto the LAN via `br0`; LUKS unlocked from the TPM (PCR 7). Backups are a TrueNAS pull, not a push — see "Backing up srv-01"; monitoring is split with the NAS — see "Monitoring srv-01"; the media stack is in "Media on srv-01", the ebook one in "Books on srv-01" (which is also the only container on this host), Paperless plus the scanner in "Documents on srv-01", Mealie in "Recipes on srv-01", Radicale in "Calendars and contacts on srv-01", and CouchDB in "Obsidian sync on srv-01"

### Module Organization

One feature = one capability file holding its NixOS **and** home-manager config together (organized by capability, not by module class). Features contribute to merge points:
- `nixos.modules.base` — every host (boot, locale, nix settings, disko, user account + nushell login shell, sshd, avahi, fwupd/smartd/btrfs-scrub, cli tools, preservation, sops)
- `nixos.modules.desktop` — desktop hosts (niri, noctalia, greeter, appearance, firefox, audio, NetworkManager + CIFS, tailscale, printing client, GUI home)
- `nixos.modules.server` — srv-01 baseline (`modules/server/`); deliberately thin — only the sops file, the headless service disables and static networking
- Named opt-in aspects imported only by hosts that want them: `secureBoot` (lanzaboote; every host with a bootloader), `autoUpgrade` (pull-based nightly updates; srv-01 only), `games`, `podman`, `displaysLeshen`, `laptop`, `docker` (no host currently imports it), and the srv-01 services (`traefik`, `authelia`, `lldap`, `homepage`, `backup`, `printScan`, `homeAssistant`, `gatus`, `beszel`, `mediaLibrary`, `jellyfin`, `servarr`, `sabnzbd`, `bazarr`, `recyclarr`, `jellyseerr`, `grimmory`, `shelfmark`, `paperless`, `mealie`, `radicale`, `couchdb`)

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
- `nixpkgs`: NixOS 26.05 stable
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

**The tmpfiles race on the first switch — known, deliberately not fixed in Nix.** Preservation
orders its bind-mounts `Before=systemd-tmpfiles-setup.service`, the *boot* unit. A `switch` never
runs that one; it runs `systemd-tmpfiles-resetup.service`, ordered only after `local-fs.target` and
knowing nothing about `preservation.target`. So on the activation that **first** introduces a
preserved directory the two race, tmpfiles usually wins, and it creates the contents on the tmpfs
root — where the bind-mount then goes on top and hides them. The service comes up against an empty
directory, and the *same* config is fine after a reboot, which makes it easy to misdiagnose as a
flaky service.

The fix is one command, on the host, with the mounts already up:

```bash
sudo systemd-tmpfiles --create
```

It is idempotent, and it repairs ownership and modes too — so it also cleans up after a directory
someone created by hand with the wrong owner.

Only services whose state directory *contents* come from tmpfiles rules are affected; anything
using `StateDirectory=` is immune, because systemd creates that at service start, long after the
mounts. That is why nothing hit it until `paperless` and `printScan` (Paperless's `consume`/`media`,
and scanservjs's `data/preview/default.jpg`, which is an `L+` symlink — its absence shows up as
`ENOENT: no such file or directory, open 'data/preview/default.jpg'`).

Two tempting fixes that do **not** work, so nobody re-derives them:

- Ordering `systemd-tmpfiles-resetup.service` after `preservation.target`. systemd applies an
  ordering dependency only when *both* units are being started; on an incremental switch the target
  is already active and only the new mount unit starts, so the edge never bites.
- An `ExecStartPre` on the service running `systemd-tmpfiles --create --prefix=…`. NixOS renders
  `preStart` as the *first* `ExecStartPre`, so a repair appended in `serviceConfig` runs after the
  module's own pre-start — which for Paperless is the `migrate` that needs the directories.
  It would need `mkBefore`, at which point the machinery outweighs a one-command, once-per-service
  papercut.

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
- Network shares auto-mount from `//nas.lan/` via CIFS with SOPS credentials — **on the desktops
  only**. srv-01 has no CIFS mount left: it reaches the one `main/media` dataset over NFS instead
  (`modules/server/media-library.nix`). `/mnt/media` on a desktop is the same tree, over SMB.
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
- Named opt-in aspects: `secureBoot`, `autoUpgrade`, `games`, `podman`, `displaysLeshen`, `laptop`, `docker`, `traefik`, `authelia`, `lldap`, `homepage`, `backup`, `printScan`, `homeAssistant`, `gatus`, `beszel`, `mediaLibrary`, `jellyfin`, `servarr`, `sabnzbd`, `bazarr`, `recyclarr`, `jellyseerr`, `grimmory`, `shelfmark`, `paperless`, `mealie`, `radicale`, `couchdb`

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
