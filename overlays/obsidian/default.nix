{ channels, ... }:
_final: prev:
with prev.lib;
let
  inherit (channels.unstable) obsidian electron_25 libglvnd;
in
{
  obsidian = throwIf (versionOlder "1.4.16" obsidian.version) "Obsidian no longer requires EOL Electron" (
    obsidian.override {
      electron = electron_25.overrideAttrs (_: {
        preFixup = "patchelf --add-needed ${libglvnd}/lib/libEGL.so.1 $out/bin/electron"; # NixOS/nixpkgs#272912
        meta.knownVulnerabilities = [ ]; # NixOS/nixpkgs#273611
      });
    }
  );
}
