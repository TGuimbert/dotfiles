{ ... }:
{
  # The agent half only. The hub runs on the TrueNAS, from its Community-train
  # catalog app, and that placement is the point rather than a convenience: a hub
  # here could not report that this host had stopped answering. The NAS upgrades
  # by hand and does not reboot nightly, so it is the stabler of the two. The
  # reverse direction is ./gatus.nix, which watches the NAS from here.
  #
  # No agent runs on the NAS itself: there is no catalog app for it
  # (truenas/apps#4729), SMART detection is broken on TrueNAS CE
  # (henrygd/beszel#1521) and disk I/O never reports, so it would be a
  # hand-maintained container duplicating the Reporting tab while still missing
  # the pool and SMART alerts. Those stay with TrueNAS's own alert engine.
  nixos.modules.beszel =
    { config, constants, ... }:
    {
      homepageTiles.Admin = [
        {
          Beszel = {
            icon = "beszel.png";
            href = "https://beszel.${constants.domain}";
            siteMonitor = "https://beszel.${constants.domain}";
            description = "Host metrics (hub runs on the NAS)";
          };
        }
      ];

      sops.secrets.beszelAgentEnvironment = { };

      services.beszel.agent = {
        enable = true;
        # Holds TOKEN, minted by the hub when this system is added there, and
        # KEY, the hub's public half that the agent checks before sending its
        # fingerprint.
        environmentFile = config.sops.secrets.beszelAgentEnvironment.path;
        smartmon.enable = true;
        environment = {
          # The agent dials *out*, so 45876 stays closed here.
          #
          # https rather than the hub's LAN address and port, because beszel's
          # WebSocket handshake authenticates without encrypting: the mutual
          # Ed25519 exchange proves both ends and blocks replay, but the metrics
          # and the registration token header then cross the wire in whatever the
          # transport gives them — cleartext, over `ws://`, and that token is this
          # agent's credential. So the NAS's Traefik terminates TLS for it.
          #
          # That depends on two things there: `beszel` resolving to the NAS rather
          # than to srv-01, and its route staying out from behind the authelia
          # middleware, which would otherwise redirect the upgrade request to
          # /api/beszel/agent-connect and stop the agent connecting at all.
          #
          # The cost is that a Traefik restart on the NAS drops this connection,
          # which the hub reads as srv-01 being down — give the hub's Status alert
          # a delay rather than trusting the first drop.
          HUB_URL = "https://beszel.${constants.domain}";
          DATA_DIR = "/var/lib/beszel-agent";
        };
      };

      # The nixpkgs module sets ProtectSystem=strict and no StateDirectory, so
      # DATA_DIR above is unwritable and the agent logs "Data directory not
      # found" on every start. Not preserved: the fingerprint kept there derives
      # from /etc/machine-id, which ../preservation.nix already pins.
      systemd.services.beszel-agent.serviceConfig.StateDirectory = "beszel-agent";
    };
}
