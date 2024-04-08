{ config, pkgs, ... }: {
  environment.systemPackages = [ pkgs.tailscale ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "/secrets/tailscale/tailscale.key";
  };

  deployment.keys."tailscale.key" = {
    keyCommand = [
      "op"
      "inject"
      "-i"
      "../modules/tailscale/tailscale.key"
    ];

    destDir = "/secrets/tailscale/";
    user = "tailscale";
    group = "tailscale";
    permissions = "0600";

    uploadAt = "pre-activation";
  };
}