{ ... }:
{
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "*" = {
            forwardAgent = false;
            addKeysToAgent = "30m";
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";

            compression = true;
            setEnv = "TERM=\"xterm-256color\"";
          };
        };
        includes = [ "private-config" ];
      };

      systemd.user.services.ssh-agent = {
        Unit = {
          Description = "SSH authentication agent";
          PartOf = [ "graphical-session.target" ];
          # The yubikey keys are verify-required, so the *agent* pops the FIDO PIN
          # prompt (SSH_ASKPASS below) on every signature. Without this ordering it
          # can start before the compositor has published WAYLAND_DISPLAY/DISPLAY into
          # the systemd user environment, and a service only ever sees the environment
          # it was exec'd with — leaving askpass blind for the whole session:
          # `ssh-askpass: cannot open display` → the agent reads the empty reply as a
          # wrong PIN → `agent refused operation`.
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent";
          Environment = [
            "SSH_ASKPASS=${pkgs.seahorse}/libexec/seahorse/ssh-askpass"
            "SSH_ASKPASS_REQUIRE=force"
          ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      home.sessionVariables.SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent";

      # Declares the askpass helper above as an application. NoDisplay keeps it out
      # of the launcher; it exists so anything resolving an askpass through the
      # desktop database finds the same binary the agent is pinned to.
      home.file.".local/share/applications/ssh-askpass.desktop".text = ''
        [Desktop Entry]
        Name=SSH Askpass
        GenericName=ssh-askpass
        Type=Application
        Exec=${pkgs.seahorse}/libexec/seahorse/ssh-askpass
        Icon=seahorse
        NoDisplay=true
      '';
    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    {
      directory = ".ssh";
      mode = "0700";
    }
  ];
}
