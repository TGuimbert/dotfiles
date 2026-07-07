{ ... }:
{
  hardware = {
    facter.reportPath = ./facter.json;
    tuxedo-drivers.enable = true;
    tuxedo-control-center.enable = true;
  };
}
