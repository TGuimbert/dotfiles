{ ... }:
{
  # Baseline merge point for headless server hosts. Empty for now: srv-01's
  # baseline still lives in hosts/srv-01/default.nix (direct-imported by the
  # machine file) and migrates here in R12. Established now so srv-01 can import
  # `server` the same way desktop hosts import `desktop`.
  nixos.modules.server = { };
}
