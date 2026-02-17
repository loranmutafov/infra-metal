{ config, pkgs, ... }: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  imports = [
    ./hardware-configuration.nix
    # ../../modules/kube-worker/kube-worker.nix
  ];

  time.timeZone = "Europe/Sofia";

  reaVaultNode = {
    enabled = true;
  };

  kubeWorkerNode = {
    enabled = false;
    kubeletNodeIP = "100.88.172.51";
  };
}
