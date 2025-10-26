{ config, lib, pkgs, flakeInputs, ... }:
let
  kubeletNodeIP = null;
  kubeMasterIP = "100.123.46.40";
  kubeMasterHostname = "vmi389591.contaboserver.net";
  kubeMasterAPIServerPort = 6443;
in
{
    networking.extraHosts = ''
        100.111.220.64  vmi384815.contaboserver.net vmi384815
        100.123.46.40   vmi389591.contaboserver.net vmi389591
        100.93.103.69   vmi428314.contaboserver.net vmi428314
        100.87.42.69    vmi430563.contaboserver.net vmi430563
        100.65.102.102  vmi431810.contaboserver.net vmi431810
      '';

  # disable swap
  swapDevices = lib.mkForce [ ];

  # resolve master hostname
  networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";

  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    # kompose
    # kubectl
    flakeInputs.self.packages.kubernetes_1_32
    cri-tools
    ethtool
    socat
    conntrack-tools
    ebtables
    iptables
  ];

  services.kubernetes = let
    api = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
  in
  {
    roles = ["node"];
    masterAddress = kubeMasterHostname;

    # point kubelet and other services to kube-apiserver
    kubelet.kubeconfig.server = api;
    apiserverAddress = api;

    # use coredns
    addons.dns.enable = true;
    flannel.enable = false;
    proxy.enable = false;
    easyCerts = false;

    # kubelet = {
    #   verbosity = 3;
    # };

    caFile = ../certs/kubernetes-ca.pem;

    # certFile = ../certs/kubernetes-node-cert.pem;
    # keyFile = ../certs/kubernetes-node-key.pem;

    # needed if you use swap
    # kubelet.extraOpts = "--fail-swap-on=false";
  };
}
