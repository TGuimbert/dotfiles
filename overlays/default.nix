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
    ;

  nushellPlugins.formats = unstable.nushellPlugins.formats;

  azure-cli =
    with unstable.pkgs;
    azure-cli.withExtensions [
      azure-cli.extensions.ssh
    ];
}
