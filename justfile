# Task runner for this flake. `just` lives in the `nixos` dev shell, so direnv
# brings it in when you cd here. `just --list` for the menu.
#
# Notes that did not fit in a one-line recipe doc:
#
#   * Flake refs only see *git-tracked* files — `git add` a brand new module
#     before building or deploying, or it is invisible to every recipe below.
#   * Remote recipes take a configuration name and reach it at `<host>.local`
#     (mDNS): srv-01's address is static, so the router never learns its name.
#     Override the ssh target with a second argument, e.g. when multicast is in
#     the way: `just deploy srv-01 10.0.0.57`.
#   * `deploy` wraps nh, which handles the SSH copy and remote activation. If its
#     remote privilege elevation ever misbehaves, the equivalent is:
#       nixos-rebuild switch --flake .#<host> --target-host <host> --sudo --ask-sudo-password

# Host acted on when a recipe takes no argument (an attribute of nixosConfigurations).
srv := "srv-01"

default:
    @just --list

# Format the tree
fmt:
    nix fmt

# Format-check, lint and evaluate every host + shell — what CI's `check` job runs
check:
    nix fmt -- --ci
    statix check
    nix flake check --no-build

# Build a host's toplevel without activating anything
build host:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel

# Switch the machine you are sitting at
switch:
    nh os switch

# Build here, push the closure over SSH, activate it on the target
deploy host=srv target=(host + ".local"):
    nh os switch --target-host {{ target }} --hostname {{ host }} .

# Same, but only make it the boot default — for changes that want a reboot
deploy-boot host=srv target=(host + ".local"):
    nh os boot --target-host {{ target }} --hostname {{ host }} .

# -t because sudo needs a terminal to prompt and ssh only allocates one on request
# Run the server's pull-based upgrade now instead of waiting for tonight's timer
upgrade-now host=srv target=(host + ".local"):
    ssh -t {{ target }} sudo systemctl start nixos-upgrade.service

# Show the last pull-based upgrades — spans two nights, so a skipped run shows as an absence
upgrade-log host=srv target=(host + ".local"):
    ssh {{ target }} journalctl -u nixos-upgrade --since -2d --no-pager

# What Renovate does weekly — for when you cannot wait for the PR
update:
    nix flake update
