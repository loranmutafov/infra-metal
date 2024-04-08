{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kube-node.nix
    ../../modules/tailscale/tailnet.nix
  ];
}