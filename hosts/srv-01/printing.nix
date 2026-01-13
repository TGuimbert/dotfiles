{ pkgs, ... }:
let
  printerName = "Samsung_M2070";
  proxyPort = 631;
  printCommand = pkgs.writeScript "print-proxy" ''
    #!${pkgs.runtimeShell}
    # $1 is the filename provided by ippeveprinter
    ${pkgs.cups}/bin/lp -d "${printerName}" \
      -o media=A4 \
      "$1"
    return_code=$?
    rm -f "$1"
    exit $return_code
  '';
in
{
  hardware.printers = {
    # ensureDefaultPrinter = printerName;
    ensurePrinters = [
      {
        name = printerName;
        location = "Home";
        deviceUri = "usb://Samsung/M2070%20Series?serial=07H1B8KJ6D002AP&interface=1";
        model = "Samsung_M2070_Series.ppd.gz";
        ppdOptions = {
          Quality = "1200dpi";
          PageSize = "A4";
        };
      }
    ];
  };
  services = {
    printing = {
      enable = true;
      drivers = with pkgs; [
        samsung-unified-linux-driver_1_00_37
      ];
      listenAddresses = [ ];
      browsing = false;
      defaultShared = false;
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };
    };
  };

  systemd.services.ipp-proxy = {
    description = "IPP Everywhere Proxy for Samsung Printer";
    wantedBy = [ "multi-user.target" ];
    after = [
      "cups.service"
      "avahi-daemon.service"
    ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs.cups}/bin/ippeveprinter \
          -v \
          -p ${toString proxyPort} \
          -M IPP \
          -m Everywhere \
          -l Home \
          -f "application/pdf,image/urf,image/pwg-raster,image/jpeg" \
          -c "${printCommand}" \
          "Samsung_Airprint"
      '';

      Restart = "always";
      RestartSec = 5;
    };
  };

  networking.firewall.allowedTCPPorts = [ proxyPort ];
}
