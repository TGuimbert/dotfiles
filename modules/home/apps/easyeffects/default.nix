{ ... }:
{
  services = {
    easyeffects = {
      enable = true;
      preset = "NoiseIsCancelled";
    };
  };

  home.file = {
    EasyEffectInputPreset = {
      target = ".config/easyeffects/input/NoiseCancelling.json";
      source = ./NoiseCancelling.json;
    };
    LoudnessEqualizer = {
      target = ".config/easyeffects/output/LoudnessEqualizer.json";
      source = ./LoudnessEqualizer.json;
    };
    SimpleEQ = {
      target = ".config/easyeffects/output/SimpleEQ.json";
      source = ./SimpleEQ.json;
    };
  };
}
