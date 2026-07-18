{ ... }:
{
  # uv / pip / npm caches + config. The tools themselves come from dev shells;
  # this aspect only persists their per-user state.
  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert = {
    directories = [
      ".aws"
      ".cache/pip"
      ".cache/pre-commit"
      ".cache/uv"
    ];
    files = [
      ".npmrc"
      ".pip/pip.conf"
      ".config/uv/uv.toml"
    ];
  };
}
