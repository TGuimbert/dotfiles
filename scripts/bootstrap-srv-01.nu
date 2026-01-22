#!/usr/bin/env nu

let ip = "nixos"
let ssh_pw = "password"

# Create a temporary directory
let tmp_path = mktemp -d

# Function to cleanup temporary directory on exit
def cleanup [] {
  rm -r $tmp_path
}

let key_path = $tmp_path | path join "persistent/etc/ssh/ssh_host_ed25519_key"
let pub_path = $tmp_path | path join "persistent/etc/ssh/ssh_host_ed25519_key.pub"

# Create the directory where sshd expects to find the host keys
install -d -m755 ( $key_path | path dirname )

# Decrypt your private key from the password store and copy it to the temporary directory
let srv_secret = bw get item srv-01 | from json 

if $srv_secret != null {
  $srv_secret | get fields | where name == "private key" | get value.0 | str replace \n "\n" --all | save $key_path
  $srv_secret | get fields | where name == "public key" | get value.0 | save $pub_path

  # Set the correct permissions so sshd will accept the key
  chmod 600 $key_path
  chmod 644 $pub_path

  # Install NixOS to the host system with our secrets
  $env.SSHPASS = ($ssh_pw)
  nix run github:nix-community/nixos-anywhere -- --extra-files $tmp_path --flake '.#srv-01' --target-host root@($ip) --env-password
}


cleanup

