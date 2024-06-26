let
  # To get the latest commit hash and the sha:
  # nix-shell -p
  # nix-prefetch-url --unpack https://github.com/nixos/nixpkgs/archive/$(git ls-remote https://github.com/nixos/nixpkgs nixos-23.11 | cut -f1).tar.gz
  # https://nora.codes/post/pinning-nixpkgs-with-morph-and-colmena/
  nixos_23_11 = builtins.fetchTarball {
    name = "nixos-23.11-2024-04-14";
    url = "https://github.com/nixos/nixpkgs/archive/51651a540816273b67bc4dedea2d37d116c5f7fe.tar.gz";
    sha256 = "1f7d0blzwqcrvz94yj1whlnfibi5m6wzx0jqfn640xm5h9bwbm3r";
  };
in {
  meta = {
    # Override to pin the Nixpkgs version (recommended). This option
    # accepts one of the following:
    # - A path to a Nixpkgs checkout
    # - The Nixpkgs lambda (e.g., import <nixpkgs>)
    # - An initialized Nixpkgs attribute set
    nixpkgs = (import nixos_23_11) {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };

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

  defaults = { pkgs, ... }: {
    # This module will be imported by all hosts
    nixpkgs.overlays = [ (import ./overlays.nix) ];

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networking.networkmanager.enable = true;

    # Set your time zone.
    time.timeZone = "Europe/Sofia";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_GB.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };

    # Configure keymap in X11
    services.xserver = {
      layout = "gb";
      xkbVariant = "";
    };

    # Configure console keymap
    console.keyMap = "uk";

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.loran = {
      isNormalUser = true;
      description = "Loran";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC8Wq1OkCqp0xRWr5qKs0e7EZf6VlSqnsVMzbexkR4LdgvqMvNc2fFCFnKcdJiCs+1XEJSmMa33DQLc53S1164SngEwO2yJOtwX8NIh010GHODafIOgcXzxAgNQQXDXj0G4Pkn63g/UMBZ2guVpPZZ5z1oziKaLtXbAfL6eYl8V0DzOTqdFR6wPIqKXGaS+Pr1caaY+xVkLLARxC7DHliV4pfj/95Jrqkgt8c2BiPxitl/fJsRc1ZccARt9Jw4ZJ3rp11fKbL7UYAkoTXaOpAYdrUXhv/x5FhY/HZlTgmrSYwApdI1EUs1PMcYg/bGWO+iwK/2xr4UTnah8xl3BwXBr+HAVlaZLhvH9d7slwuDvcpYQm1jjFtQlER4K0oH73W7dSoVpzxZN2jq5KZ5nKLY/oInwCSTD4NXKCghhvCdQpdouKe7O99jI5S/gFSs2xtHUVo09dXIGR5I275FqyTJy+mT9scx8TvXYeqT74vLhoR9zkadugfp9vQTe+66E8y8= loran@Lorans-MacBook-Pro.local"
      ];
    };

    # Enable sudo logins if the user’s SSH agent provides a key present in
    # ~/.ssh/authorized_keys. This allows machines to exclusively use SSH
    # keys instead of passwords.
    # services.openssh.settings.KbdInteractiveAuthentication = false;
    # services.openssh.settings.PermitRootLogin = "yes";
    # services.openssh.settings.PasswordAuthentication = true;
    # services.openssh.settings.X11Forwarding = true;
    # security.sudo.enable = true;
    security.pam.enableSSHAgentAuth = true;
    security.pam.services.sudo.sshAgentAuth = true;

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      vim
      curl
      dig
      inetutils
      btop
      cloudflared
    ];

    # nixpkgs.overlays = [ (self: super: {
    #   cloudflared = (super.cloudflared.override {
    #     buildGoModule = pkgs.buildGo121Module;
    #   }).overrideAttrs (old: rec {
    #     version = "2024.1.5";
    #     src = super.fetchFromGitHub {
    #       owner = "cloudflare";
    #       repo = "cloudflared";
    #       rev = "refs/tags/2024.1.5";
    #       sha256 = "sha256-g7FUwEs/wEcX1vRgfoQZw+uMzx6ng3j4vFwhlHs6WKg=";
    #     };
    #   });
    # }) ];

    # cloudflared config:
    # {
    #   "ingress": [
    #     {
    #       "hostname": "vpc1.royal.technology",
    #       "originRequest":{},
    #       "path":"nina",
    #       "service":"ssh://localhost:22"
    #     },
    #     {
    #       "service":"http_status:404"
    #     }
    #   ],
    #   "warp-routing":{
    #     "enabled":true
    #   }
    # }

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # programs.mtr.enable = true;
    # programs.gnupg.agent = {
    #   enable = true;
    #   enableSSHSupport = true;
    # };

    # List services that you want to enable:

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;

    # Open ports in the firewall.
    networking.firewall.allowedTCPPorts = [ 22 10250 ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    networking.firewall.enable = false;

    # By default, Colmena will replace unknown remote profile
    # (unknown means the profile isn't in the nix store on the
    # host running Colmena) during apply (with the default goal,
    # boot, and switch).
    # If you share a hive with others, or use multiple machines,
    # and are not careful to always commit/push/pull changes
    # you can accidentaly overwrite a remote profile so in those
    # scenarios you might want to change this default to false.
    # deployment.replaceUnknownProfiles = true;
  };

  metal-nina = { name, nodes, ... }: {
    time.timeZone = "Europe/Sofia";

    # Like NixOps and morph, Colmena will attempt to connect to
    # the remote host using the attribute name by default. You
    # can override it like:
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

    # Like NixOps and morph, Colmena will attempt to connect to
    # the remote host using the attribute name by default. You
    # can override it like:
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

    # Like NixOps and morph, Colmena will attempt to connect to
    # the remote host using the attribute name by default. You
    # can override it like:
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
