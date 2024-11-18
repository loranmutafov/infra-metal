{ config, pkgs, name, lib, ... }:
with lib; let
  bind = name;
  cfg = config.reaVaultNode;
in
{
  options.reaVaultNode = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    deployment.tags = [ "vault" ];
    systemd.tmpfiles.rules = [ "d /vault/data 1777 root root -" ];

    services.vault = {
      package = pkgs.vault-bin;
      enable = true;
      storageBackend = "raft";

      address = "0.0.0.0:8200";
      storageConfig = ''
        # node_id = "node1"
        path = "/vault/data"

        # nina
        retry_join {
            leader_api_addr         = "https://metal-nina:8200"
            leader_tls_servername   = "vault.rea.loran.dev"
            leader_ca_cert_file     = "/secrets/rea/rea-root.cert"
            leader_client_cert_file = "/secrets/vault/vault-intermediate.cert"
            leader_client_key_file  = "/secrets/vault/vault-intermediate.key"
        }

        retry_join {
            leader_api_addr         = "https://metal-eli:8200"
            leader_tls_servername   = "vault.rea.loran.dev"
            leader_ca_cert_file     = "/secrets/rea/rea-root.cert"
            leader_client_cert_file = "/secrets/vault/vault-intermediate.cert"
            leader_client_key_file  = "/secrets/vault/vault-intermediate.key"
        }

        retry_join {
            leader_api_addr         = "https://metal-100yan:8200"
            leader_tls_servername   = "vault.rea.loran.dev"
            leader_ca_cert_file     = "/secrets/rea/rea-root.cert"
            leader_client_cert_file = "/secrets/vault/vault-intermediate.cert"
            leader_client_key_file  = "/secrets/vault/vault-intermediate.key"
        }
      '';

      tlsCertFile = "/secrets/vault/vault-intermediate.cert";
      tlsKeyFile = "/secrets/vault/vault-intermediate.key";

      extraConfig = ''
        cluster_name = "Rea's Metal Vault"

        api_addr = "https://0.0.0.0:8200"
        cluster_addr = "https://${bind}:8201"
        ui = true

        disable_mlock = true
        telemetry {
          # at /v1/sys/metrics
          disable_hostname = true
        }
      '';

      listenerExtraConfig = ''
        # for checking client, not mandatory
        tls_client_ca_file = "/secrets/rea/rea-root.cert"
        cluster_address = "0.0.0.0:8201"
        # tls_disable_client_certs = true
      '';
    };

    deployment.keys."vault-intermediate.key" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/vault-intermediate.key" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };
    deployment.keys."vault-intermediate.cert" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/vault-intermediate.cert" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };

    # Certs for metal-nina
    deployment.keys."metal-nina.cert" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/metal-nina.cert" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };
    deployment.keys."metal-nina.key" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/metal-nina.key" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };

    # Certs for metal-eli
    deployment.keys."metal-eli.cert" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/metal-eli.cert" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };
    deployment.keys."metal-eli.key" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/metal-eli.key" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };

    # Certs for metal-100yan
    deployment.keys."metal-100yan.cert" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/metal-100yan.cert" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };
    deployment.keys."metal-100yan.key" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/metal-100yan.key" ];

      destDir = "/secrets/vault/";
      user = "vault";
      group = "vault";
      permissions = "0600";

      uploadAt = "pre-activation";
    };

    systemd.services.vault = {
      partOf = [
        "rea-root.cert.service"
        "raft.key.service"
        "raft.cert.service"
        "vault-intermediate.key.service"
        "vault-intermediate.cert.service"
      ];

      after = [ "tailscale-autoconnect.service" ];
    };
  };
}
