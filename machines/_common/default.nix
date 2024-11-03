{ pkgs, ... }: {
  deployment.keys."rea-root.cert" = {
    keyCommand = [ "op" "inject" "-i" "../certs/rea-root.cert" ];

    destDir = "/secrets/rea/";
    permissions = "0600";

    uploadAt = "pre-activation";
  };

  imports = [
    ./config.nix
    ../../modules/tailscale/tailnet.nix
  ];
}
