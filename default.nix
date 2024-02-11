with import <nixpkgs> { system = "x86_64-linux"; };

{
  imports = [
    ./machines
  ];
}
