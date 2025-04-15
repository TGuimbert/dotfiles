{ channels, ... }:
_final: _prev: {
  inherit (channels.unstable) k9s;
}
