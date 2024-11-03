{
  description = "FLAKES!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgsWithKubernetes126.url = "github:NixOS/nixpkgs/1b7a6a6e57661d7d4e0775658930059b77ce94a4";

    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, utils, nixpkgsWithKubernetes126 }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgsk8s126 = nixpkgsWithKubernetes126.legacyPackages.x86_64-linux;
  in
  {
    packages.tailscale_latest = pkgs.tailscale;
    packages.kubernetes_1_26 = pkgsk8s126.kubernetes;

    colmena = (import ./hive.nix) (inputs);
  };
}
