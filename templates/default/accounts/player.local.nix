# Operator-local identity for `player`. Gitignored. Never publish this file.
#
# Populates the framework's per-user identity slots so the tracked tree
# can carry no personal data. See docs/REFACTOR-PLAN.md Stage 5.
{ ... }:
{
  myOS.users.player.identity = {
    git.name  = "Elaina";
    git.email = "48662592+oestradiol@users.noreply.github.com";

    audio.micSourceAlias   = "alsa_input.usb-3142_Fifine_Microphone-00.mono-fallback";
    audio.micLoopbackSink  = "alsa_output.pci-0000_09_00.4.analog-stereo";

    workspace.autoUpdateRepoPath = "/home/player/dotfiles";
  };
}
