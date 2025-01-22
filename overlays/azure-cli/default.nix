{ channels, ... }:
_final: _prev: {
  azure-cli =
    with channels.unstable.pkgs;
    azure-cli.withExtensions [
      azure-cli.extensions.ssh
    ];
}
