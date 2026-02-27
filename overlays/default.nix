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
    ;

  nushellPlugins.formats = unstable.nushellPlugins.formats;

  azure-cli =
    with unstable.pkgs;
    azure-cli.withExtensions [
      azure-cli.extensions.ssh
    ];

  # Temporary fix to this issue: https://github.com/NixOS/nixpkgs/issues/467783#issuecomment-3621306981
  freecad = prev.freecad.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.wrapGAppsHook3 ];
  });
}
