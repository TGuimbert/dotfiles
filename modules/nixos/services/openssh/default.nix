{ ... }:
{
  config = {
    services.openssh = {
      enable = true;
    };
    environment.persistence."/persistent" = {
      files = [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };
  };
}
