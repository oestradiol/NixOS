# PipeWire low-latency audio — important for VR and gaming
{ ... }: {
  # Disable PulseAudio — PipeWire replaces it entirely
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;  # Required for 32-bit game audio (Proton/Wine)
    pulse.enable = true;       # PulseAudio compatibility layer
    jack.enable = true;        # JACK compatibility — used by some pro audio/VR apps
    wireplumber.enable = true; # Session/policy manager for PipeWire
  };

  # Realtime scheduling for audio threads — reduces audio dropouts in VR
  security.rtkit.enable = true;
}
