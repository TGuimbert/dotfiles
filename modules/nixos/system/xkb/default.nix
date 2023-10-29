{ ... }:
{
  # Configure keymap in X11
  services.xserver = {
    layout = "fr";
    xkbVariant = "bepo";
  };
  # Configure console keymap
  console.keyMap = "fr";
}
