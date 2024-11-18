{ pkgs, ... }: {
  deployment.keys."rea-root.cert" = {
    keyFile = ../../certs/rea-root.cert;

    destDir = "/secrets/rea/";
    permissions = "0644";

    uploadAt = "pre-activation";
  };

  security.pki.certificateFiles = [
    ../../certs/rea-root.cert
  ];

  imports = [
    ./config.nix
    ../../modules/tailscale/tailnet.nix
    ../../modules/vault/vault-instance.nix
  ];
}
