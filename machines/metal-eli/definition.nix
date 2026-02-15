{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/kube-worker/kube-worker.nix
  ];

  time.timeZone = "Europe/Sofia";

  networking.firewall.enable = false;

  reaVaultNode = {
    enabled = true;
  };

  kubeWorkerNode = {
    enabled = false;
    kubeletNodeIP = "100.91.190.115";
  };
}
