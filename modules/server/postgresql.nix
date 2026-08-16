{ ... }:
{
  # The PostgreSQL cluster, owned by one aspect rather than by whichever service
  # asked for it first. ./paperless.nix turns it on through `database.createLocally`
  # and ./miniflux.nix has no other engine to choose from, so left where it was the
  # preserved data directory would belong to one of them and the other would depend
  # on that aspect being imported without saying so — the trap ./mealie.nix
  # documents from the other side.
  nixos.modules.postgresql =
    { config, lib, ... }:
    let
      # The *parent*, not `services.postgresql.dataDir`, which carries the major
      # version: pinning that would land the next cluster on the tmpfs root.
      dataDir = "/var/lib/postgresql";
    in
    {
      services.postgresql.enable = true;

      # Called by the aspects that keep their state in here, in ./gatus.nix's
      # `mkHeartbeat` idiom: taking the argument is what makes a host importing
      # one of them without this one fail to evaluate. The assertion covers the
      # other half — this aspect imported, the preservation entry edited away.
      _module.args.requirePostgresql = service: {
        assertion = lib.any (
          entry: entry.directory == dataDir
        ) config.preservation.preserveAt."/persistent".directories;
        message = ''
          ${service} keeps its state in PostgreSQL, but ${dataDir} is not preserved:
          the cluster would live on the tmpfs root and be empty after every reboot.
        '';
      };

      # No uid pinning, unlike most sibling aspects: nixpkgs allocates postgres
      # statically (`ids.uids.postgres = 71`), so it survives a rebuild already.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = dataDir;
          user = "postgres";
          group = "postgres";
          mode = "0750";
        }
      ];
    };
}
