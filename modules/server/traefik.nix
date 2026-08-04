{ ... }:
{
  nixos.modules.traefik =
    { config, constants, ... }:
    {
      # Recorded from `getent passwd`, not chosen — see ../preservation.nix.
      users = {
        users.traefik.uid = 993;
        groups.traefik.gid = 988;
      };

      homepageTiles.Admin = [
        {
          "Traefik srv-01" = {
            icon = "traefik.png";
            href = "https://traefik.${constants.domain}/dashboard/";
            siteMonitor = "https://traefik.${constants.domain}/dashboard/";
            description = "Reverse proxy";
          };
        }
      ];

      sops.secrets.traefikEnvironments = { };
      services.traefik = {
        enable = true;
        environmentFiles = [ config.sops.secrets.traefikEnvironments.path ];
        staticConfigOptions = {
          api = {
            dashboard = true;
            debug = false;
            insecure = false;
          };
          entryPoints = {
            web = {
              address = ":80";
              http.redirections.entrypoint = {
                to = "websecure";
                scheme = "https";
              };
            };
            websecure = {
              address = ":443";
              # The NAS's Traefik reaches Authelia through this one, and an
              # untrusted peer's X-Forwarded-* is discarded — Authelia would then
              # see auth.<domain> as the target and answer 400. Both addresses are
              # the same host. Not a subnet: the trust spans every route here, and
              # a trusted peer may claim any host.
              forwardedHeaders.trustedIPs = [
                "10.0.0.55"
                "10.0.0.56"
              ];
              http.tls = {
                certResolver = "cloudflareDns";
                # One wildcard instead of the per-router certificate Traefik
                # otherwise infers from each `Host()` rule, so no subdomain
                # reaches the CT logs. `*.` covers one label and never the
                # apex, hence the apex as `main` and the wildcard as a SAN.
                domains = [
                  {
                    main = constants.domain;
                    sans = [ "*.${constants.domain}" ];
                  }
                ];
              };
            };
            ldapsecure = {
              address = ":636";
            };
          };
          certificatesResolvers = {
            cloudflareDns = {
              acme = {
                email = "letsencrypt.malformed915@simplelogin.com";
                storage = "acme.json";
                dnsChallenge = {
                  provider = "cloudflare";
                  resolvers = [
                    "1.1.1.1:53"
                    "1.0.0.1:53"
                  ];
                };
              };
            };
          };
          tls = {
            options.default = {
              minVersion = "VersionTLS12";
              cipherSuites = [
                "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
                "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
                "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
                "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
                "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305"
                "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
              ];
            };
            stores.default.defaultGeneratedCert = {
              resolver = "cloudflareDns";
              domain = {
                main = constants.domain;
                sans = [ "*.${constants.domain}" ];
              };
            };
          };
        };
        dynamicConfigOptions = {
          http.routers.dashboard = {
            rule = "Host(`traefik.${constants.domain}`)";
            entrypoints = [ "websecure" ];
            middlewares = [ "authelia" ];
            service = "api@internal";
          };
        };
      };
      preservation.preserveAt."/persistent" = {
        directories = [
          # Ownership spelled out: preservation.conf sorts after nixpkgs'
          # 00-nixos.conf, so a bare path string wins the tie and resets this to
          # root:root 0755, leaving traefik unable to write acme.json.
          {
            directory = config.services.traefik.dataDir;
            user = "traefik";
            inherit (config.services.traefik) group;
            mode = "0700";
          }
        ];
      };
      networking.firewall.allowedTCPPorts = [
        80
        443
        636
      ];
    };
}
