{ unstable }:
final: prev: {
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

  azure-cli =
    with unstable.pkgs;
    azure-cli.withExtensions [
      azure-cli.extensions.ssh
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
  aiven-client = prev.callPackage ../packages/aiven-client { };
}
