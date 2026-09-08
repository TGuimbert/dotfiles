{ config, ... }:
{
  homeManager.modules = {
    gui.imports = [ config.homeManager.modules.gpg ];

    gpg = { pkgs, ... }: {
      imports = [ config.homeManager.modules.git ];

      programs.gpg = {
        enable = true;
        publicKeys = [
          {
            source = builtins.fetchurl {
              url = "https://github.com/TGuimbert.gpg";
              sha256 = "07b7gfhr13923jv7vfdnq80rpahgdzd8anxy07876395ywsrnvkb";
            };
            trust = 5;
          }
          {
            source = builtins.fetchurl {
              url = "https://github.com/web-flow.gpg";
              sha256 = "117gldk49gc76y7wqq6a4kjgkrlmdsrb33qw2l1z9wqcys3zd2kf";
            };
          }
        ];
        scdaemonSettings = {
          reader-port = "Yubico Yubi";
          disable-ccid = true;
        };
      };

      services.gpg-agent = {
        enable = true;
        enableSshSupport = false;
        pinentry.package = if pkgs.stdenv.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-gnome3;
      };

      programs.git.signing = {
        signByDefault = true;
        # Git passes the full user identity to GPG when this is unset. The key's
        # UID uses a different display name, so select it by fingerprint instead.
        key = "3E71BB9D2E95AD28D351E67711C1D08CC148FEBC";
      };
    };
  };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    {
      directory = ".gnupg";
      mode = "0700";
    }
  ];
}
