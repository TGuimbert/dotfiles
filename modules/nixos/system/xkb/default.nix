{ ... }:
{
  # Configure keymap in X11
  services.xserver = {
    xkb = {
      layout = "fr";
      variant = "bepo";
    };
  };
  # Configure console keymap
  console.keyMap = "fr";
}
