{ pkgs, ... }:
let
  publicKey = builtins.fetchurl {
    url = "https://github.com/TGuimbert.gpg";
    sha256 = "84860ac53b31e30cdbdb3ac88cf20ac78827370b5782b8038e646616293368a9";
  };
in
{
  programs.gpg = {
    enable = true;
    publicKeys = [
      {
        source = publicKey;
        trust = 5;
      }
    ];
    scdaemonSettings = {
      reader-port = "Yubico Yubi";
      disable-ccid = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
