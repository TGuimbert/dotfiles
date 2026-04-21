{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  footWrapped = inputs.nix-wrapper-modules.wrappers.foot.wrap {
    inherit pkgs;
    settings.main.shell = "nu -c 'zellij -l welcome'";
    settings.main.initial-window-mode = "maximized";
  };
in
{
  options.features.shell.terminal.enable = lib.mkEnableOption "foot terminal" // {
    default = true;
  };

  config = lib.mkIf config.features.shell.terminal.enable {
    home.packages = [ footWrapped ];

    programs.bash.enable = true;

    home.sessionPath = [ "$HOME/.local/bin" ];

    home.sessionVariables = {
      ZELLIJ_AUTO_ATTACH = "true";
      ZELLIJ_AUTO_EXIT = "true";
    };

    systemd.user.services.foot-server = {
      Unit = {
        Description = "Foot terminal server mode";
        Documentation = "man:foot(1)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${footWrapped}/bin/foot --server";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.persistence."/persistent".files = [
      ".bash_history"
    ];
  };
}
