{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    # ../../modules/kube-worker/kube-worker.nix
  ];

  time.timeZone = "Europe/Sofia";

  reaVaultNode = {
    enable = true;
  };
}
