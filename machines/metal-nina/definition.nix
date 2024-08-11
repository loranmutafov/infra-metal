{ config, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  imports = [
    ./hardware-configuration.nix
    # ../../modules/kube-node.nix
    ../../modules/tailscale/tailnet.nix
  ];
}