inputs@{ nixpkgs, disko, ... }:
let
  hive = import ./hive.nix inputs;

  # Hosts currently authorized for nixos-anywhere bootstrap installs.
  # Adding a host here authorizes `nix run nixos-anywhere -- --flake .#<name> ...`
  # to wipe its disks and reinstall NixOS.
  #
  # REMOVE A HOST FROM THIS LIST AS SOON AS IT'S INSTALLED AND STABLE.
  # Otherwise a typo against the wrong IP could reformat a live machine.
  installable = [
    "vps-ionos-ber-1"
  ];

  # Stub for Colmena's `deployment` option. `_common/default.nix` uses
  # `deployment.keys.*` unconditionally, which fails in plain `nixosSystem`
  # without Colmena's option module. The stub accepts any `deployment.*` attrs
  # and ignores them — Colmena uploads the actual keys later via `make deploy`.
  colmenaDeploymentStub = { lib, ... }: {
    options.deployment = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
  };

  mkConfig = name: nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit name; nodes = {}; flakeInputs = inputs; };
    modules = [
      colmenaDeploymentStub
      disko.nixosModules.disko
      ./${name}/disko.nix
      hive.defaults
      hive.${name}
    ];
  };
in
nixpkgs.lib.genAttrs installable mkConfig
