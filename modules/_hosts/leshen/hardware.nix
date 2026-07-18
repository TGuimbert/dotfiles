{ ... }:
{
  hardware.facter.reportPath = ./facter.json;

  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = false;
  };

  networking.hostId = "42dea791";
}
