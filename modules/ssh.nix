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
    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    {
      directory = ".ssh";
      mode = "0700";
    }
  ];
}
