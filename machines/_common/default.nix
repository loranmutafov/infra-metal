{ pkgs, ... }: {
  imports = [
    ./config.nix
    ../../modules/tailscale/tailnet.nix
  ];
}
