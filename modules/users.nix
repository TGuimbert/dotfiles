{
  config,
  inputs,
  lib,
  ...
}:
{
  config = {
    nixos.modules.base = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      users.users.tguimbert = {
        isNormalUser = true;
        uid = 1000;
      };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.tguimbert =
          { osConfig, ... }:
          {
            # mkDefault so the legacy home/ module's explicit stateVersion keeps
            # winning until it is refactored (R8). Without this, hosts whose system
            # stateVersion differs from home/'s hardcoded "22.11" (e.g. tuxedo at
            # 25.11) hit a conflicting-definition error.
            home.stateVersion = lib.mkDefault osConfig.system.stateVersion;
            imports = [ config.homeManager.modules.base ];
          };
      };
    };
    nixos.modules.desktop = {
      home-manager.users.tguimbert.imports = [ config.homeManager.modules.gui ];
    };
  };
}
