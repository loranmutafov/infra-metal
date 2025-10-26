{
  description = "FLAKES!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # https://github.com/NixOS/nixpkgs/commit/550b7205534015391c39f067441b537e57db8b73
    # https://github.com/NixOS/nixpkgs/commits/nixos-25.05/pkgs/applications/networking/cluster/kubernetes/default.nix
    nixpkgsWithKubernetes132.url = "github:NixOS/nixpkgs/550b7205534015391c39f067441b537e57db8b73";

    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, utils, nixpkgsWithKubernetes132 }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgsk8s132 = nixpkgsWithKubernetes132.legacyPackages.x86_64-linux;
  in
  {
    packages.tailscale_latest = pkgs.tailscale;
    packages.kubernetes_1_32 = pkgsk8s132.kubernetes;

    colmena = (import ./hive.nix) (inputs);
  };
}
