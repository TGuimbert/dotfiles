use std

$env.config = {
  show_banner: false
  buffer_editor: 'hx'
}

$env.path ++= ["~/.local/bin"]

alias ll = ls -la
alias k = kubectl
alias cat = bat

# List existing Zellij layouts (excluding homepage)
def available-layouts [] {
  ls ~/.config/zellij/layouts/ | get name | path parse | get stem | where {|x| $x != "homepage" }
}

# Replace current Zellij tab with a new one based on the specified layout
def replace-with-layout [layout: string@available-layouts] {
  let temp_tab_name = random chars 
  zellij action rename-tab $temp_tab_name
  zellij action new-tab --layout $layout --name ($env.PWD | path basename)
  zellij action go-to-tab-name $temp_tab_name
  zellij action close-tab 
}

# Open in a browser a local copy of the rust documentation
def open-rust-doc [] {
  xdg-open (nix build fenix#latest.rust-docs --json --no-link | from json | first | get outputs.out | path join share/doc/rust/html/index.html)
}

if ("~/.gnupg/S.gpg-agent.ssh" | path exists) {
  $env.SSH_AUTH_SOCK = "~/.gnupg/S.gpg-agent.ssh"
  $env.GPG_TTY = ^tty
  ^gpg-connect-agent updatestartuptty /bye o> (std null-device)
}
