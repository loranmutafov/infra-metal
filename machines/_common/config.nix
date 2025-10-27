{ pkgs, ... }: {
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    
    gc.automatic = true;
    gc.options = "--delete-older-than 60d";
    gc.dates = "daily";
    optimise.automatic = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    dig
    inetutils
    btop
    cloudflared
  ];

  users.users.loran = {
    isNormalUser = true;
    description = "Loran";
    extraGroups = [ "networkmanager" "wheel" ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC8Wq1OkCqp0xRWr5qKs0e7EZf6VlSqnsVMzbexkR4LdgvqMvNc2fFCFnKcdJiCs+1XEJSmMa33DQLc53S1164SngEwO2yJOtwX8NIh010GHODafIOgcXzxAgNQQXDXj0G4Pkn63g/UMBZ2guVpPZZ5z1oziKaLtXbAfL6eYl8V0DzOTqdFR6wPIqKXGaS+Pr1caaY+xVkLLARxC7DHliV4pfj/95Jrqkgt8c2BiPxitl/fJsRc1ZccARt9Jw4ZJ3rp11fKbL7UYAkoTXaOpAYdrUXhv/x5FhY/HZlTgmrSYwApdI1EUs1PMcYg/bGWO+iwK/2xr4UTnah8xl3BwXBr+HAVlaZLhvH9d7slwuDvcpYQm1jjFtQlER4K0oH73W7dSoVpzxZN2jq5KZ5nKLY/oInwCSTD4NXKCghhvCdQpdouKe7O99jI5S/gFSs2xtHUVo09dXIGR5I275FqyTJy+mT9scx8TvXYeqT74vLhoR9zkadugfp9vQTe+66E8y8= loran@Lorans-MacBook-Pro.local"
    ];
  };

  # Enable sudo logins if the user’s SSH agent provides a key present in
  # ~/.ssh/authorized_keys. This allows machines to exclusively use SSH
  # keys instead of passwords.
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

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
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

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
  networking.firewall.allowedTCPPorts = [ 22 10250 8200 8201 ];
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
}