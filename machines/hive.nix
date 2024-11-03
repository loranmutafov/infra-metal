inputs@{ nixpkgs, utils, ... }: {
  meta = {
    # Override to pin the Nixpkgs version (recommended). This option
    # accepts one of the following:
    # - A path to a Nixpkgs checkout
    # - The Nixpkgs lambda (e.g., import <nixpkgs>)
    # - An initialized Nixpkgs attribute set
    nixpkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    specialArgs.flakeInputs = inputs;

    # You can also override Nixpkgs by node!
    # nodeNixpkgs = {
    #   node-b = ./another-nixos-checkout;
    # };

    # If your Colmena host has nix configured to allow for remote builds
    # (for nix-daemon, your user being included in trusted-users)
    # you can set a machines file that will be passed to the underlying
    # nix-store command during derivation realization as a builders option.
    # For example, if you support multiple orginizations each with their own
    # build machine(s) you can ensure that builds only take place on your
    # local machine and/or the machines specified in this file.
    # machinesFile = ./machines.client-a;
  };

  defaults = { name, lib, ... }: {
    # This module will be imported by all hosts
    # nixpkgs.overlays = [ (import ./overlays.nix) ];
    imports = [
      ./${name}/definition.nix
      ./_common
    ];

    nixpkgs = {
      system = lib.mkDefault "x86_64-linux";
      config.allowUnfree = true;
    };
  };

  metal-nina = { name, nodes, ... }: {
    time.timeZone = "Europe/Sofia";

    deployment.targetHost = "metal-nina";
    deployment.targetUser = "loran";
    deployment.buildOnTarget = true;

    services.cloudflared = {
      enable = true;
      tunnels = {
        "a1b3b7f8-8ed5-4881-9fe2-46767dcd74b6" = {
          credentialsFile = "/secrets/cloudflared/cloudflared-credentials.secret";
          default = "http_status:404";

          ingress = {
            "metal-1.loran.dev" = {
              service = "ssh://localhost:22";
              path = "";
            };
          };
        };
      };
    };

    deployment.keys."cloudflared-credentials.secret" = {
      # Alternatively, `text` (string) or `keyFile` (path to file)
      # may be specified.
      # keyFile = ./metal-nina/cloudflared-2023.10.0;
      keyCommand = [
        "op"
        "inject"
        "-i"
        "./metal-nina/cloudflared-2023.10.0.tpl"
      ];

      destDir = "/secrets/cloudflared/";
      user = "cloudflared";
      group = "cloudflared";
      permissions = "0600";

      uploadAt = "pre-activation"; # Default: pre-activation, Alternative: post-activation
    };

    # The name and nodes parameters are supported in Colmena,
    # allowing you to reference configurations in other nodes.
    networking.hostName = name;
    # time.timeZone = nodes.host-b.config.time.timeZone;

    imports = [
      ./metal-nina/definition.nix
    ];

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "23.11"; # Did you read the comment?
  };

  metal-100yan = { name, nodes, ... }: {
    time.timeZone = "Europe/Sofia";

    deployment.targetHost = "metal-100yan";
    deployment.targetUser = "loran";
    deployment.buildOnTarget = true;

    services.cloudflared = {
      enable = true;
      tunnels = {
        "a1b3b7f8-8ed5-4881-9fe2-46767dcd74b6" = {
          credentialsFile = "/secrets/cloudflared/cloudflared-credentials.secret";
          default = "http_status:404";

          ingress = {
            "metal-100yan.loran.dev" = {
              service = "ssh://localhost:22";
              path = "";
            };
          };
        };
      };
    };

    deployment.keys."cloudflared-credentials.secret" = {
      keyCommand = [
        "op"
        "inject"
        "-i"
        "./metal-100yan/cloudflared-2023.10.0.tpl"
      ];

      destDir = "/secrets/cloudflared/";
      user = "cloudflared";
      group = "cloudflared";
      permissions = "0600";

      uploadAt = "pre-activation"; # Default: pre-activation, Alternative: post-activation
    };

    # The name and nodes parameters are supported in Colmena,
    # allowing you to reference configurations in other nodes.
    networking.hostName = name;
    # time.timeZone = nodes.host-b.config.time.timeZone;

    imports = [
      ./metal-100yan/definition.nix
    ];

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "23.11"; # Did you read the comment?
  };

  metal-eli = { name, nodes, ... }: {
    time.timeZone = "Europe/Sofia";

    deployment.targetHost = "metal-eli";
    deployment.targetUser = "loran";
    deployment.buildOnTarget = true;

    services.cloudflared = {
      enable = true;
      tunnels = {
        "a1b3b7f8-8ed5-4881-9fe2-46767dcd74b6" = {
          credentialsFile = "/secrets/cloudflared/cloudflared-credentials.secret";
          default = "http_status:404";

          ingress = {
            "metal-eli.loran.dev" = {
              service = "ssh://localhost:22";
              path = "";
            };
          };
        };
      };
    };

    deployment.keys."cloudflared-credentials.secret" = {
      keyCommand = [
        "op"
        "inject"
        "-i"
        "./metal-eli/cloudflared-2023.10.0.tpl"
      ];

      destDir = "/secrets/cloudflared/";
      user = "cloudflared";
      group = "cloudflared";
      permissions = "0600";

      uploadAt = "pre-activation"; # Default: pre-activation, Alternative: post-activation
    };

    # The name and nodes parameters are supported in Colmena,
    # allowing you to reference configurations in other nodes.
    networking.hostName = name;
    # time.timeZone = nodes.host-b.config.time.timeZone;

    imports = [
      ./metal-eli/definition.nix
    ];

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "23.11"; # Did you read the comment?
  };
}
