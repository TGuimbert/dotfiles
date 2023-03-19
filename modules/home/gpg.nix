{ ... }:
let
  publicKey = builtins.fetchurl {
    url = "https://github.com/TGuimbert.gpg";
    sha256 = "0c63m4w4z6jsn1glsq5hlf18rl71zj4y4qa7z717w6rf6yx7b9xs";
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
  };

  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "gnome3";
  };
}
