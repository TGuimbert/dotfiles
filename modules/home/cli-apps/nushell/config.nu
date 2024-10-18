$env.config = {
  show_banner: false
}


const private_config_path = /home/tguimbert/.config/nushell/private.nu
touch $private_config_path
source $private_config_path
