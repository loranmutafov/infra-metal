final: prev:
# https://nixos.wiki/wiki/Overlays
let
  # master = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz") pkgs-config;
  # unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/unstable.tar.gz") pkgs-config;
  pkgsWithKubernetes123 = import (
    builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/7592790b9e02f7f99ddcb1bd33fd44ff8df6a9a7.tar.gz"
  ) pkgs-config;
  pkgsWithKubernetes126 = import (
    builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/1b7a6a6e57661d7d4e0775658930059b77ce94a4.tar.gz"
  ) pkgs-config;

  # pkgsWithKubernetes119 = import (builtins.fetchGit {
  #   name = "with-kubernetes-1-19";
  #   # url = "https://github.com/nixos/nixpkgs.git";
  #   url = "https://github.com/nixos/nixpkgs-channels.git";
  #   ref = "refs/heads/nixpkgs-unstable";
  #   rev = "5c1ffb7a9fc96f2d64ed3523c2bdd379bdb7b471"; 
  # }) pkgs-config;

  pkgs-config = {
    config.allowUnfree = true;
    system = prev.system;
  };
in
{
  kubernetes_1_23 = pkgsWithKubernetes123.kubernetes;
  kubernetes_1_26 = pkgsWithKubernetes126.kubernetes;
}
