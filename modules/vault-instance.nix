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

      storageConfig = ./vault-raft.conf
      address = "${bind}:8200"
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

      tlsKeyFile = "/opt/vault/tls/vault-key.rsa";
      tlsCertFile = "/opt/vault/tls/vault-ca.pem";
      listenerExtraConfig = ''
        # for checking client, not mandatory
        tls_client_ca_file = "/opt/vault/tls/vault-ca.pem"
        cluster_address = "${bind}:8201"
      '';
    };

    deployment.keys."vault-key.rsa" = {
      keyFile = secretPath + "/pki/vault/key.rsa";
      destDir = "/opt/vault/tls";
      user = "root";
      group = "vault";
      permissions = "0640"
    };
    deployment.keys."vault-cert.pem" = {
      keyFile = secretPath + "/pki/vault/mesh-cert-chain.pem";
      destDir = "/opt/vault/tls";
      user = "root";
      group = "root";
      permissions = "0644";
    };
    deployment.keys."vault-ca.pem" = {
      keyFile = secretPath + "/pki/vault/mesh-ca.pem";
      destDir = "/opt/vault/tls";
      user = "root";
      group = "root";
      permissions = "0644";
    };

    systemd.services.vault = {
      partOf = {
        "vault-key.pem.service"
        "vault-cert.pem.service"
        "vault-ca.pem.service"
      };
      after = [ "tailscale-autoconnect" ]
    }
  }
}
