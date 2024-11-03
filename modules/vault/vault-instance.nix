{ config, pkgs, name, config, ... }:
let
  bind = name;
  cfg = config.reaVaultNode;
in
{
  options.reaVaultNode = {
    enable = mkOption {
      type = types.bool;
      default = false;
    }
  }

  config = mkIf cfg.enable {
    services.vault = {
      enable = true;
      storageBackend = "raft";

      storageConfig = ./vault-raft.conf;
      address = "${bind}:8200";
      extraConfig = ''
        cluster_name = "Rea's Metal Vault"

        api_addr = "https://${bind}:8200"
        cluster_addr = "https://${bind}:8201"
        ui = true

        disable_mlock = true
        telemetry {
          # at /v1/sys/metrics
          disable_hostname = true
        }
      '';

      tlsKeyFile = "/secrets/vault/vault-intermediate.key";
      tlsCertFile = "/secrets/vault/vault-intermediate.cert";
      listenerExtraConfig = ''
        # for checking client, not mandatory
        tls_client_ca_file = "/secrets/vault/vault-intermediate.cert"
        cluster_address = "${bind}:8201"
      '';
    };

    deployment.keys."vault-intermediate.key" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/vault-intermediate.key" ];

      destDir = "/secrets/vault/";
      permissions = "0640";

      uploadAt = "pre-activation";
    };
    deployment.keys."vault-intermediate.cert" = {
      keyCommand = [ "op" "inject" "-i" "../modules/vault/certs/vault-intermediate.cert" ];

      destDir = "/secrets/vault/";
      permissions = "0640";

      uploadAt = "pre-activation";
    };

    systemd.services.vault = {
      partOf = {
        "rea-root.cert"
        "vault-intermediate.key.service"
        "vault-intermediate.cert.service"
      };
      after = [ "tailscale-autoconnect" ]
    }
  }
}
