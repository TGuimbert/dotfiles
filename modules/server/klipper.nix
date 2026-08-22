{ ... }:
{
  # A Traefik route and a homepage tile, and nothing else — the only aspect here
  # that runs no service on this host. Klipper, Moonraker and the Fluidd UI live
  # on the printer, which used to terminate its own TLS; this puts the name under
  # the wildcard certificate ./traefik.nix already holds and makes the hop plain
  # HTTP, the ./home-assistant.nix shape.
  #
  # One router covers everything, because the printer's nginx on :80 serves
  # Fluidd *and* already proxies Moonraker and the webcam. Nothing needs
  # middleware: Traefik forwards `Upgrade`, does not buffer responses and sets no
  # request-body limit, so /websocket, the MJPEG stream and gcode upload all
  # work.
  #
  # Moonraker needs nothing in return — the counterpoint to ./home-assistant.nix's
  # trusted_proxies block, so nobody copies it. Its trusted_clients already covers
  # this host and Fluidd calls the origin it was served from, so cors_domains is
  # never consulted. Proxying does collapse every client into srv-01's address,
  # which costs nothing while the whole RFC1918 space is trusted.
  nixos.modules.klipper =
    {
      constants,
      mkRouter,
      ...
    }:
    {
      homepageTiles.Services = [
        {
          Klipper = {
            icon = "klipper.png";
            href = "https://klipper.${constants.domain}";
            siteMonitor = "https://klipper.${constants.domain}";
            description = "3D printer management";
          };
        }
      ];

      # `mkRouter`, not `mkAutheliaRouter`, joining ./jellyfin.nix and the rest:
      # the browser is one client among several, and the slicer's network upload,
      # Mobileraker and the webcam stream can no more complete an SSO round trip
      # than a TV can.
      #
      # A name and not the literal address ./home-assistant.nix pins, so Traefik
      # re-resolves per request and a changed DHCP lease needs no rebuild. That
      # makes the two names load-bearing in opposite directions: `klipper.lan`
      # must keep pointing at the printer — which also leaves it reachable there
      # directly — while only `klipper.<domain>` moves here, or this route
      # proxies to itself.
      services.traefik.dynamicConfigOptions.http = mkRouter {
        name = "klipper";
        url = "http://klipper.lan";
      };
    };
}
