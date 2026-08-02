{ ... }:
{
  # Inject the Traefik `http` block builders as module args for server aspects:
  # a router plus its loadBalancer service, from a name and a backend. Closes
  # over `constants.domain` so subdomains stay in sync with the shared domain.
  # `mkAutheliaRouter` is the common case — everything on this host sits behind
  # SSO except Home Assistant, which authenticates its own clients.
  nixos.modules.server =
    { constants, lib, ... }:
    let
      mkRouter =
        {
          name,
          port ? null,
          url ? "http://localhost:${toString port}",
          subdomain ? name,
          middlewares ? [ ],
        }:
        {
          routers.${name} = {
            rule = "Host(`${subdomain}.${constants.domain}`)";
            entrypoints = [ "websecure" ];
            service = name;
          }
          // lib.optionalAttrs (middlewares != [ ]) { inherit middlewares; };
          services.${name}.loadBalancer.servers = [ { inherit url; } ];
        };
    in
    {
      _module.args = {
        inherit mkRouter;
        mkAutheliaRouter = args: mkRouter (args // { middlewares = [ "authelia" ]; });
      };
    };
}
