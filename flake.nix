{
  description = "Outline Wiki - Arion configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # The arion-compose.nix is in the root of the repo
    # and will be imported directly by the NixOS module
  };
}