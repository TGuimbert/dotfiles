{ inputs, ... }:
let
  overlay = final: prev: let
    unstable = import inputs.unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  in {
    inherit (unstable)
      helix
      k9s
      carapace
      obsidian
      orca-slicer
      rustfinity
      base16-schemes
      nushell
      calibre
      tidal-hifi
      claude-code
      ;

    nushellPlugins.formats = unstable.nushellPlugins.formats;

    azure-cli = unstable.azure-cli.withExtensions [
      unstable.azure-cli.extensions.ssh
    ];

    # Fix missing GTK schema crash on file dialogs: https://github.com/NixOS/nixpkgs/issues/467783
    freecad = prev.symlinkJoin {
      name = "freecad-wrapped";
      paths = [ prev.freecad ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/FreeCAD \
          --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}"
      '';
    };

    # Custom packages
    aiven-client = prev.callPackage ../../packages/aiven-client { };
  };
in
{
  flake.overlays.default = overlay;

  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ overlay ];
    };
  };
}
