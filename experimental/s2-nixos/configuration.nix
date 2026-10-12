{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix = {
    channel.enable = false;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  systemd.network.enable = true;

  networking = {
    firewall.enable = true;
    nftables.enable = true;

    useHostResolvConf = false;
  };

  time.timeZone = "Etc/UTC";

  services.userborn.enable = true;
  users = {
    groups.sprite.gid = 1000;
    users.sprite = {
      isNormalUser = true;
      uid = 1000;
      group = "sprite";
      extraGroups = [ "wheel" ];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  system.disableInstallerTools = true;
  environment = {
    defaultPackages = [ ];
    systemPackages = with pkgs; [
      nixos-rebuild
    ];
    stub-ld.enable = false;
  };
  programs = {
    command-not-found.enable = false;
  };
  documentation = {
    doc.enable = false;
    info.enable = false;
  };
  fonts.fontconfig.enable = false;
  xdg = {
    autostart.enable = false;
    icons.enable = false;
    menus.enable = false;
    mime.enable = false;
    sounds.enable = false;
  };

  system.stateVersion = "26.05";
}
