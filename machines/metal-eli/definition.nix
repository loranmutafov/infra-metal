{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    # ../../modules/kube-node.nix
  ];

  time.timeZone = "Europe/Sofia";
}
