{ ... }:
{
  # The Samsung M2070 hanging off srv-01's USB port, both halves of it. One
  # device, one cable, one proprietary driver derivation — splitting printing and
  # scanning into two aspects would mean two files that must always be imported
  # together to describe one thing.
  nixos.modules.printScan =
    {
      constants,
      mkAutheliaRouter,
      pkgs,
      ...
    }:
    let
      printerName = "Samsung_M2070";
      proxyPort = 631;
      scanPort = 8086;

      # One derivation for both halves: rastertospl for the CUPS queue,
      # libsane-smfp with its dll.d entry and udev rules for the scanner.
      driver = pkgs.samsung-unified-linux-driver_1_00_37;

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

      # What the proxy *advertises*, as opposed to what the queue above prints
      # on. It is a whole capability set rather than a paper-size override
      # because ippeveprinter hardcodes US Letter unless given `-a`, and refuses
      # `-a` alongside `-M`/`-m`/`-f`. Captured from a live instance running
      # those flags and edited, so the only intended deltas are the media ones.
      # What that costs and how to re-verify it: ../../CLAUDE.md, "Documents on
      # srv-01".
      printerAttrs = pkgs.writeText "samsung-airprint.conf" ''
        ATTR boolean color-supported false
        ATTR integer copies-default 1
        ATTR rangeOfInteger copies-supported 1-999
        ATTR integer document-password-supported 1023
        ATTR keyword finishing-template-supported none
        ATTR collection finishings-col-database { MEMBER keyword finishing-template none }
        ATTR collection finishings-col-default { MEMBER keyword finishing-template none }
        ATTR collection finishings-col-ready { MEMBER keyword finishing-template none }
        ATTR keyword finishings-col-supported finishing-template
        ATTR enum finishings-default 3
        ATTR enum finishings-ready 3
        ATTR enum finishings-supported 3

        # The point of the whole file: A4 as the default and as the loaded
        # media. Letter and Legal stay *selectable* so a one-off is still
        # possible, but they are no longer what a client picks unprompted.
        ATTR keyword media-default iso_a4_210x297mm
        ATTR keyword media-ready iso_a4_210x297mm,iso_dl_110x220mm
        ATTR keyword media-supported iso_a4_210x297mm,iso_a5_148x210mm,iso_dl_110x220mm,na_letter_8.5x11in,na_legal_8.5x14in
        ATTR integer media-bottom-margin-supported 0,1168
        ATTR integer media-left-margin-supported 340,635
        ATTR integer media-right-margin-supported 340,635
        ATTR integer media-top-margin-supported 0,102
        ATTR keyword media-source-supported auto,main,manual,by-pass-tray
        ATTR keyword media-type-supported auto,cardstock,envelope,labels,other,stationery,stationery-letterhead,transparency
        ATTR keyword media-col-supported media-bottom-margin,media-left-margin,media-right-margin,media-size,media-size-name,media-source,media-top-margin,media-type
        ATTR collection media-col-default { MEMBER keyword media-key iso_a4_210x297mm_main_stationery MEMBER collection media-size { MEMBER integer x-dimension 21000 MEMBER integer y-dimension 29700 } MEMBER keyword media-size-name iso_a4_210x297mm MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 MEMBER keyword media-source main MEMBER keyword media-type stationery }
        ATTR collection media-col-ready { MEMBER keyword media-key iso_a4_210x297mm_main_stationery MEMBER collection media-size { MEMBER integer x-dimension 21000 MEMBER integer y-dimension 29700 } MEMBER keyword media-size-name iso_a4_210x297mm MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 MEMBER keyword media-source main MEMBER keyword media-type stationery },{ MEMBER keyword media-key iso_dl_110x220mm_by-pass-tray_envelope MEMBER collection media-size { MEMBER integer x-dimension 11000 MEMBER integer y-dimension 22000 } MEMBER keyword media-size-name iso_dl_110x220mm MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 MEMBER keyword media-source by-pass-tray MEMBER keyword media-type envelope }
        ATTR collection media-col-database { MEMBER collection media-size { MEMBER integer x-dimension 21000 MEMBER integer y-dimension 29700 } MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 },{ MEMBER collection media-size { MEMBER integer x-dimension 14800 MEMBER integer y-dimension 21000 } MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 },{ MEMBER collection media-size { MEMBER integer x-dimension 11000 MEMBER integer y-dimension 22000 } MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 },{ MEMBER collection media-size { MEMBER integer x-dimension 21590 MEMBER integer y-dimension 27940 } MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 },{ MEMBER collection media-size { MEMBER integer x-dimension 21590 MEMBER integer y-dimension 35560 } MEMBER integer media-bottom-margin 635 MEMBER integer media-left-margin 635 MEMBER integer media-right-margin 635 MEMBER integer media-top-margin 635 }
        ATTR collection media-size-supported { MEMBER integer x-dimension 21000 MEMBER integer y-dimension 29700 },{ MEMBER integer x-dimension 14800 MEMBER integer y-dimension 21000 },{ MEMBER integer x-dimension 11000 MEMBER integer y-dimension 22000 },{ MEMBER integer x-dimension 21590 MEMBER integer y-dimension 27940 },{ MEMBER integer x-dimension 21590 MEMBER integer y-dimension 35560 }

        # 3 is portrait, 4/5/6 the rotations; 4 is normal quality, 3/5 draft
        # and high. Enums rather than keywords because that is what IPP defines
        # for these two attributes.
        ATTR enum orientation-requested-default 3
        ATTR enum orientation-requested-supported 3,4,5,6
        ATTR enum print-quality-default 4
        ATTR enum print-quality-supported 3,4,5

        ATTR keyword output-bin-default face-down
        ATTR keyword output-bin-supported face-down
        ATTR keyword overrides-supported document-numbers,media,media-col,orientation-requested,pages
        ATTR boolean page-ranges-supported true
        ATTR integer pages-per-minute 20
        ATTR keyword print-color-mode-default monochrome
        ATTR keyword print-color-mode-supported monochrome
        ATTR keyword print-content-optimize-default auto
        ATTR keyword print-content-optimize-supported auto
        ATTR keyword print-rendering-intent-default auto
        ATTR keyword print-rendering-intent-supported auto
        ATTR keyword sides-default one-sided
        ATTR keyword sides-supported one-sided

        # Quoted because the parser splits unquoted values on whitespace, and
        # on commas — an unquoted `CMD:PWG,URF;` becomes two values and the
        # model name loses everything after the first word.
        ATTR text printer-device-id "MFG:Samsung;MDL:M2070 Series;CMD:PWG,URF;"
        ATTR text printer-make-and-model "Samsung M2070 Series"

        ATTR resolution printer-resolution-default 600dpi
        ATTR resolution printer-resolution-supported 600dpi
        ATTR resolution pwg-raster-document-resolution-supported 300dpi,600dpi
        ATTR keyword pwg-raster-document-type-supported black_1,sgray_8
        ATTR keyword pwg-raster-document-sheet-back normal
        ATTR keyword urf-supported CP1,IS1-4-5-19,MT1-2-3-4-5-6,RS600,V1.4,W8

        # `level=-2` is IPP's "unknown", which is the truth: this host proxies a
        # USB printer and cannot read a tray or a cartridge. Upstream's legacy
        # defaults invent a full tray and 75% toner; those were tried here to fix
        # a phone reporting the printer "blocked" and did not, so they are not
        # kept — see ../../CLAUDE.md before re-running that experiment.
        ATTR octetString printer-input-tray "type=sheetFeedAutoRemovableTray;mediafeed=0;mediaxfeed=0;maxcapacity=-2;level=-2;status=0;name=auto","type=sheetFeedAutoRemovableTray;mediafeed=29700;mediaxfeed=21000;maxcapacity=250;level=-2;status=0;name=main","type=sheetFeedManual;mediafeed=0;mediaxfeed=0;maxcapacity=1;level=-2;status=0;name=manual","type=sheetFeedAutoNonRemovableTray;mediafeed=0;mediaxfeed=0;maxcapacity=25;level=-2;status=0;name=by-pass-tray"
        ATTR octetString printer-supply "index=1;class=receptacleThatIsFilled;type=wasteToner;unit=percent;maxcapacity=100;level=-2;colorantname=unknown;","index=2;class=supplyThatIsConsumed;type=toner;unit=percent;maxcapacity=100;level=-2;colorantname=black;"
        ATTR text printer-supply-description "Toner Waste Tank","Black Toner"
      '';
    in
    {
      # The nixpkgs module creates this account without an id, and it now owns
      # preserved state — see ../preservation.nix for why a dynamically allocated
      # uid cannot. 358 is ./shelfmark.nix.
      users = {
        users.scanservjs.uid = 359;
        groups.scanservjs.gid = 359;
      };

      homepageTiles.Services = [
        {
          Scanner = {
            icon = "scanservjs.png";
            href = "https://scan.${constants.domain}";
            siteMonitor = "https://scan.${constants.domain}";
            description = "Scan from the M2070";
          };
        }
      ];

      hardware = {
        printers = {
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

        # `extraBackends` also installs the driver's udev rules through
        # `services.udev.packages` and ACLs the device to the `scanner` group,
        # which the scanservjs module already puts its user in.
        sane = {
          enable = true;
          extraBackends = [ driver ];
        };
      };

      services = {
        printing = {
          enable = true;
          drivers = [ driver ];
          listenAddresses = [ ];
          browsing = false;
          defaultShared = false;
        };
        # ippeveprinter (below) registers its _ipp._tcp record through the avahi
        # client API, which this permits; the daemon is in `modules/services.nix`.
        avahi.publish.userServices = true;

        # Deliberately files nothing: the output directory is an inbox, and
        # ./paperless.nix contributes a "Send to Paperless" action rather than
        # pointing it at a consume directory. A scan is not automatically a
        # document — photos and pages scanned to email land here too.
        scanservjs = {
          enable = true;
          settings = {
            host = "127.0.0.1";
            port = scanPort;
          };
        };

        # Browser-only, so the same treatment as the *arr in ./servarr.nix.
        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "scan";
          port = scanPort;
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
              -l Home \
              -a "${printerAttrs}" \
              -c "${printCommand}" \
              "Samsung_Airprint"
          '';

          Restart = "always";
          RestartSec = 5;
        };
      };

      # Holds scans that have not been filed yet, which a tmpfs root would
      # otherwise lose on the next reboot. Deliberately *not* in ./backup.nix
      # though: it is an inbox, not an archive. Anything worth keeping is either
      # sent to Paperless, which is backed up, or downloaded from the UI — a
      # scanned photo belongs in Immich on the NAS, not here.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/scanservjs";
          user = "scanservjs";
          group = "scanservjs";
          mode = "0750";
        }
      ];

      networking.firewall.allowedTCPPorts = [ proxyPort ];
    };
}
