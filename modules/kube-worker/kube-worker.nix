{ config, lib, pkgs, name, flakeInputs, ... }:
with lib; let
  kubeletHostname = name;
  kubeMasterIP = "100.123.46.40";
  kubeMasterHostname = "vmi389591.contaboserver.net";
  kubeMasterAPIServerPort = 6443;
  cfg = config.kubeWorkerNode;
in
{
  options.kubeWorkerNode = {
    enabled = mkOption {
      type = types.bool;
      default = false;
    };
    kubeletNodeIP = mkOption {
      type = types.str;
      default = null;
    };
  };

  config = mkIf cfg.enabled {
    networking.extraHosts = ''
      100.123.46.40   vmi389591.contaboserver.net vmi389591
      100.111.220.64  vmi384815.contaboserver.net vmi384815
      100.93.103.69   vmi428314.contaboserver.net vmi428314
      100.87.42.69    vmi430563.contaboserver.net vmi430563
      100.65.102.102  vmi431810.contaboserver.net vmi431810
    '';

    # Allow Cilium Wireguard UDP port
    # https://docs.cilium.io/en/stable/operations/system_requirements/
    networking.firewall.allowedUDPPorts = [ 51871 ];

    # https://nixos.wiki/wiki/Kubernetes
    boot.kernelModules = [ "ceph" "rbd" "nbd" ];

    # disable swap
    swapDevices = lib.mkForce [ ];

    # packages for administration tasks
    environment.systemPackages = with pkgs; [
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
      package = flakeInputs.self.packages.kubernetes_1_32;
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
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/cluster/kubernetes/kubelet.nix
      kubelet = {
        nodeIp = cfg.kubeletNodeIP;

        # Don't manage CNI plugins via Nix - let Cilium install them
        cni.packages = lib.mkForce [];

        kubeconfig = {
          server = api;
          caFile = ../../certs/kubernetes-ca.pem;
          certFile = "/secrets/kube-worker/kubelet-${kubeletHostname}.cert";
          keyFile = "/secrets/kube-worker/kubelet-${kubeletHostname}.key";
        };
        extraOpts = "--root-dir=/var/lib/kubelet --rotate-server-certificates=true --client-ca-file=${../../certs/kubernetes-ca.pem}";
      };

      # needed if you use swap
      # kubelet.extraOpts = "--fail-swap-on=false";
    };

    # Cilium doesn't usually set the Services CIDR for some reason
    # We set it, because we won't be able to find it otherwise with our
    # Tailscale setup.
    networking.interfaces.cilium_host.ipv4.routes = [{
      address = "10.96.0.0";
      prefixLength = 12;
    }];

    # Enable IP forwarding so Tailscale can route subnet traffic through this node
    services.tailscale.useRoutingFeatures = "server";

    # Dynamically discover this node's Cilium pod CIDR and advertise it via Tailscale.
    # Cilium IPAM allocates each node a /24 from the cluster pod CIDR. We read the
    # cilium_host interface IP to derive it, then tell Tailscale to advertise the route.
    systemd.services.tailscale-advertise-pod-cidr = {
      description = "Advertise Cilium pod CIDR via Tailscale";
      after = [ "tailscaled.service" "kubelet.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      path = with pkgs; [ iproute2 tailscale gawk ];

      script = ''
        # Wait for cilium_host interface to get an IP from Cilium IPAM
        echo "Waiting for cilium_host interface to receive an IP..."
        while true; do
          CILIUM_IP=$(ip -4 addr show cilium_host 2>/dev/null | awk '/inet / {split($2, a, "/"); print a[1]}')
          if [ -n "$CILIUM_IP" ]; then
            break
          fi
          sleep 5
        done

        # Derive the /24 subnet from the allocated IP
        IFS='.' read -r a b c d <<< "$CILIUM_IP"
        POD_CIDR="''${a}.''${b}.''${c}.0/24"

        echo "Advertising pod CIDR $POD_CIDR via Tailscale"
        tailscale set --advertise-routes="$POD_CIDR"
      '';
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
  };
}
