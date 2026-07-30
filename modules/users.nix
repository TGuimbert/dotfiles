{
  config,
  inputs,
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
            # The user's home tracks the host's stateVersion.
            home.stateVersion = osConfig.system.stateVersion;
            imports = [ config.homeManager.modules.base ];
          };
      };
    };
    nixos.modules.desktop = {
      home-manager.users.tguimbert.imports = [ config.homeManager.modules.gui ];
    };
  };
}
