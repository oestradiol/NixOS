# User account, groups, shell
{ pkgs, ... }: {
  users.users.ruby = {
    isNormalUser = true;
    description = "Ruby";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "realtime"
      "gamemode" # Feral GameMode performance daemon
      "render"   # GPU render node access (Vulkan compute, VR)
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
}
