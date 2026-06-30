{ ... }:
{
  # Inject `mkAutheliaRouter` as a module arg for server aspects: builds the
  # repeated Traefik `http` block (an authelia-protected router + its
  # loadBalancer service) from a service name + local port. Closes over
  # `constants.domain` so subdomains stay in sync with the shared domain.
  nixos.modules.server =
    { constants, ... }:
    {
      _module.args.mkAutheliaRouter =
        {
          name,
          port,
          subdomain ? name,
        }:
        {
          routers.${name} = {
            rule = "Host(`${subdomain}.${constants.domain}`)";
            entrypoints = [ "websecure" ];
            middlewares = [ "authelia" ];
            service = name;
          };
          services.${name}.loadBalancer.servers = [
            { url = "http://localhost:${toString port}"; }
          ];
        };
    };
}
