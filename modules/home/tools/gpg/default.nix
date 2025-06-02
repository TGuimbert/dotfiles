{ pkgs, ... }:
let
  publicKey = builtins.fetchurl {
    url = "https://github.com/TGuimbert.gpg";
    sha256 = "07b7gfhr13923jv7vfdnq80rpahgdzd8anxy07876395ywsrnvkb";
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
    pinentry.package = pkgs.pinentry-gnome3;
  };
}
