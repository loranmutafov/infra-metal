{ config, pkgs, lib, ... }:
with lib; let
  cfg = config.reaTailnet;
in
{
  options.reaTailnet = {
    enabled = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enabled {
    environment.systemPackages = [ pkgs.tailscale ];

    # https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/services/networking/tailscale.nix
    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = "/secrets/tailscale/tailscale.key";
    };

    deployment.keys."tailscale.key" = {
      keyCommand = [ "op" "inject" "-i" "../modules/tailscale/tailscale.key" ];

      destDir = "/secrets/tailscale/";
      permissions = "0600";

      uploadAt = "pre-activation";
    };

    # Tell the Kernel about Tailscale IP ranges to simplify everything
    networking.interfaces.tailscale0.ipv4.routes = [{
      address = "100.64.0.0";
      prefixLength = 10;
    }];

    systemd.services.tailscaled.after = ["NetworkManager-wait-online.service"];
  };
}
