{ config, ... }:
{
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
          http.tls.certResolver = "cloudflareDns";
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
            main = "home.guimbert.fr";
            sans = [ "lldap.home.guimbert.fr" ];
          };
        };
      };
    };
    dynamicConfigOptions = {
      http.routers.dashboard = {
        rule = "Host(`traefik.home.guimbert.fr`)";
        entrypoints = [ "websecure" ];
        middlewares = [ "authelia" ];
        service = "api@internal";
      };
    };
  };
  environment.persistence."/persistent" = {
    directories = [
      config.services.traefik.dataDir
    ];
  };
  networking.firewall.allowedTCPPorts = [
    80
    443
    636
  ];
}
