{ config, pkgs, ... }: {
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

  systemd.services.tailscaled.after = ["NetworkManager-wait-online.service"];
}
