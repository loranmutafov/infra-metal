{ config, lib, pkgs, name, flakeInputs, ... }:
let
  kubeletHostname = name;
  kubeletNodeIP = null;
  kubeMasterIP = "100.123.46.40";
  kubeMasterHostname = "vmi389591.contaboserver.net";
  kubeMasterAPIServerPort = 6443;
in
{
  networking.extraHosts = ''
    100.123.46.40   vmi389591.contaboserver.net vmi389591
    100.111.220.64  vmi384815.contaboserver.net vmi384815
    100.93.103.69   vmi428314.contaboserver.net vmi428314
    100.87.42.69    vmi430563.contaboserver.net vmi430563
    100.65.102.102  vmi431810.contaboserver.net vmi431810
  '';

  # disable swap
  swapDevices = lib.mkForce [ ];

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
    apiserverAddress = api;

    # use coredns
    addons.dns.enable = true;
    flannel.enable = false;
    proxy.enable = false;
    easyCerts = false;

    # kubelet = {
    #   verbosity = 3;
    # };

    # PKI config for kubelet
    kubelet.kubeconfig = {
      server = api;
      caFile = ../../certs/kubernetes-ca.pem;
      certFile = "/secrets/kube-worker/kubelet-${kubeletHostname}.cert";
      keyFile = "/secrets/kube-worker/kubelet-${kubeletHostname}.key";
    };
    kubelet.extraOpts = "--root-dir=/var/lib/kubelet";

    # needed if you use swap
    # kubelet.extraOpts = "--fail-swap-on=false";
  };

  # Kubelet client certs
  deployment.keys."kubelet-${kubeletHostname}.cert" = {
    keyCommand = [ "op" "inject" "-i" "../modules/kube-worker/certs/${kubeletHostname}.cert" ];

    destDir = "/secrets/kube-worker/";
    user = "kubernetes";
    group = "kubernetes";
    permissions = "0600";

    uploadAt = "pre-activation";
  };
  deployment.keys."kubelet-${kubeletHostname}.key" = {
    keyCommand = [ "op" "inject" "-i" "../modules/kube-worker/certs/${kubeletHostname}.key" ];

    destDir = "/secrets/kube-worker/";
    user = "kubernetes";
    group = "kubernetes";
    permissions = "0600";

    uploadAt = "pre-activation";
  };
}
