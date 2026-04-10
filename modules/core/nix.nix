# Nix settings: flakes, experimental features, binary caches
{ ... }: {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;

    # Prevent "download buffer is full" warnings during large builds.
    # Default is 64MB which is too small for heavy packages like the kernel.
    download-buffer-size = 524288000; # 500MB
  };

  # Periodic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
