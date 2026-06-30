{ ... }:
{
  # uv / pip / npm caches + config. The tools themselves come from dev shells;
  # this aspect only persists their per-user state.
  homeManager.modules.gui = {
    home.persistence."/persistent" = {
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
  };
}
