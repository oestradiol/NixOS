# GPU vendor selection — controls driver and VR runtime defaults
# Option declared in modules/core/options.nix; this file only routes imports.
{ ... }: {
  imports = [ ./nvidia.nix ./amd.nix ];
}
