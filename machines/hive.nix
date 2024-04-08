let
  # To get the latest commit hash and the sha:
  # nix-prefetch-url --unpack https://github.com/nixos/nixpkgs/archive/$(git ls-remote https://github.com/nixos/nixpkgs nixos-23.11 | cut -f1).tar.gz
  nixos_23_11 = builtins.fetchTarball {
    name = "nixos-23.11-2024-04-08";
    url = "https://github.com/nixos/nixpkgs/archive/e38d7cb66ea4f7a0eb6681920615dfcc30fc2920.tar.gz"; 
    sha256 = "1shml3mf52smfra0x3mpfixddr4krp3n78fc2sv07ghiphn22k43";
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

    networking.hostName = "metal-nina"; # Define your hostname.
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networking.networkmanager.enable = true;

    # Set your time zone.
    time.timeZone = "Europe/London";

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
    users.users.gustav = {
      isNormalUser = true;
      description = "Gustav";
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
    #       "path":"gustav",
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

  oxymoron = { name, nodes, ... }: {
    time.timeZone = "Europe/London";

    # Like NixOps and morph, Colmena will attempt to connect to
    # the remote host using the attribute name by default. You
    # can override it like:
    deployment.targetHost = "metal-1.loran.dev";
    deployment.targetUser = "gustav";
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
      # keyFile = ./gustav/cloudflared-2023.10.0;
      keyCommand = [
        "op"
        "inject"
        "-i"
        "./gustav/cloudflared-2023.10.0.tpl"
      ];

      destDir = "/secrets/cloudflared/";
      user = "cloudflared";
      group = "cloudflared";
      permissions = "0600";

      uploadAt = "pre-activation"; # Default: pre-activation, Alternative: post-activation
    };

    # The name and nodes parameters are supported in Colmena,
    # allowing you to reference configurations in other nodes.
    # networking.hostName = name;
    # time.timeZone = nodes.host-b.config.time.timeZone;

    imports = [
      ./gustav/definition.nix
    ];
    #
    # fileSystems."/" = {
    #   device = "/dev/disk/by-uuid/59ec8017-87b9-40e8-8f19-d5615e2740d2"; # "/dev/nvme0n1p3";
    #   fsType = "ext4";
    # };
    # fileSystems."/boot" = {
    #   device = "/dev/disk/by-uuid/CC8A-21AF"; # "/dev/nvme0n1p1";
    #   fsType = "vfat";
    # };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "23.11"; # Did you read the comment?
  };

  # host-b = {
  #   time.timeZone = "Europe/London";
  #   # Like NixOps and morph, Colmena will attempt to connect to
  #   # the remote host using the attribute name by default. You
  #   # can override it like:
  #   deployment.targetHost = "host-b.mydomain.tld";

  #   # It's also possible to override the target SSH port.
  #   # For further customization, use the SSH_CONFIG_FILE
  #   # environment variable to specify a ssh_config file.
  #   deployment.targetPort = 22;

  #   # Override the default for this target host
  #   deployment.replaceUnknownProfiles = false;

  #   # You can filter hosts by tags with --on @tag-a,@tag-b.
  #   # In this example, you can deploy to hosts with the "web" tag using:
  #   #    colmena apply --on @web
  #   # You can use globs in tag matching as well:
  #   #    colmena apply --on '@infra-*'
  #   deployment.tags = [ "web" "infra-lax" ];

  #   boot.loader.grub.device = "/dev/nvme0n1";
  #   fileSystems."/" = {
  #     device = "/dev/nvme0n1p3";
  #     fsType = "ext4";
  #   };
  # };
}
