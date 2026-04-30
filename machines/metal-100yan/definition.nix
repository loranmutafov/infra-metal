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
    kubeletNodeIP = "100.82.50.117";
  };
}
