{ pkgs, ... }:

let
  pack = "pack_1";
  theme = "colorful_loop";
  plymouth-package = pkgs.stdenv.mkDerivation {
    pname = "adi1090x-plymouth-${pack}-${theme}";
    version = "0.0.1";
    src = builtins.fetchGit {
      url = "https://github.com/adi1090x/plymouth-themes.git";
      rev = "bf2f570bee8e84c5c20caac353cbe1d811a4745f";
    };

    buildInputs = [ pkgs.git ];

    configurePhase = ''
      mkdir -p $out/share/plymouth/themes/
    '';

    buildPhase = '''';

    installPhase = ''
      cp -r ${pack}/${theme} $out/share/plymouth/themes
      cat ${pack}/${theme}/${theme}.plymouth | sed "s@\/usr\/@$out\/@" > $out/share/plymouth/themes/${theme}/${theme}.plymouth
    '';
  };
in
{
  boot.plymouth = {
    enable = true;
    themePackages = [ plymouth-package ];
  };
  boot.kernelParams = [ "quiet" ];
}
