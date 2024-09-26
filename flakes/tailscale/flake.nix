{
  description = "Reusable Tailscale config as all my machines need to run it in order to communicate with each other";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
    nixpkgs.tailscale = pkgs.tailscale;

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
      permissions = "0600";

      uploadAt = "pre-activation";
    };
  };

}