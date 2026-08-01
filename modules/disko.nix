{ inputs, ... }:
{
  # Not imported from _hosts/_lib/btrfs-disk.nix, where it belongs: that is a
  # plain parameter function reached by relative path, with no `inputs` in scope.
  nixos.modules.base = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
