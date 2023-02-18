{
	pkgs,
	config,
	lib,
	...
}: with lib; let
	cfg = config.tg.plymouth;

	adi1090x-plymouth-package-generator = { pack, theme }:
		pkgs.stdenv.mkDerivation {
			pname = "adi1090x-plymouth-${pack}-${theme}";
			version = "0.0.1";
			src = builtins.fetchGit {
				url = "https://github.com/adi1090x/plymouth-themes.git";
				rev = "bf2f570bee8e84c5c20caac353cbe1d811a4745f";
			};
		
			buildInputs = [
				pkgs.git
			];

			configurePhase = ''
				mkdir -p $out/share/plymouth/themes/
			'';

			buildPhase = ''
			'';

			installPhase = ''
				cp -r ${pack}/${theme} $out/share/plymouth/themes
				cat ${pack}/${theme}/${theme}.plymouth | sed "s@\/usr\/@$out\/@" > $out/share/plymouth/themes/${theme}/${theme}.plymouth
			'';
		};
in {
	options.tg.plymouth = {
		enable = mkOption {
			description = "Wether to enable Plymouth boot splash screen.";
			default = false;
			type = types.bool;
		};
		pack = mkOption {
			description = "The pack the theme is from.";
			default = "pack_1";
			type = types.str;
		};
		theme = mkOption {
			description = "The name of the Plymouth theme.";
			default = "colorful_loop";
			type = types.str;
		};
	};

	config = mkIf cfg.enable {
	  boot.plymouth = let
			plymouth-package = adi1090x-plymouth-package-generator { pack = cfg.pack; theme = cfg.theme; };
		in {
	    enable = true;
	    themePackages = [ plymouth-package ];
	    theme = cfg.theme;
	  };
		boot.kernelParams = ["quiet"];
	};
}
