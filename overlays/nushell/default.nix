{ channels, ... }:
_final: _prev: {
  inherit (channels.unstable) nushell;
  nushellPlugins.formats = channels.unstable.nushellPlugins.formats;
}
