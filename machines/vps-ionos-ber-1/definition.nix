{ config, lib, pkgs, flakeInputs, ... }: {
  imports = [
    flakeInputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
  ];

  time.timeZone = "Europe/Berlin";

  networking.firewall.enable = false;

  kubeWorkerNode = {
    enabled = true;
    kubeletNodeIP = "100.100.251.73";
  };

  # IONOS classic VPS firmware is SeaBIOS (legacy BIOS), not UEFI.
  # Override _common/config.nix's systemd-boot (UEFI-only) with GRUB.
  # Disko auto-registers /dev/vda as the boot device via the EF02 partition,
  # so we don't set `boot.loader.grub.device` ourselves (would duplicate).
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub.enable = true;
}
