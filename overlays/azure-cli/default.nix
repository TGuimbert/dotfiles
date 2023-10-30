{ channels, ... }:

final: prev:

{
  inherit (channels.stable) azure-cli;
}
