{
  description = "Reusable Tailscale config as all my machines need to run it in order to communicate with each other"

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.x86_64-linux
}