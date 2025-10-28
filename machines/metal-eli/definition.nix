{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/kube-worker/kube-worker.nix
  ];

  time.timeZone = "Europe/Sofia";

  reaVaultNode = {
    enabled = true;
  };

  kubeWorkerNode = {
    enabled = true;
    kubeletNodeIP = "100.91.190.115";
  };
}
