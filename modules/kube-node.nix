{ config, lib, pkgs, ... }:
let
  kubeletNodeIP = null;
  kubeMasterIP = "95.111.244.161";
  kubeMasterHostname = "kubernetes.default";
  kubeMasterAPIServerPort = 6443;
in
{
  # disable swap
  swapDevices = lib.mkForce [ ];

  # resolve master hostname
  networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";

  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    # kompose
    # kubectl
    kubernetes_1_26
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
    # kubelet.hostname = "metal-1.loran.dev";
    # certFile = ../certs/kubernetes-node-cert.pem;
    # keyFile = ../certs/kubernetes-node-key.pem;

    # needed if you use swap
    # kubelet.extraOpts = "--fail-swap-on=false";
  };
}
