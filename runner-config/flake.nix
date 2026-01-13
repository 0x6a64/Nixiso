{
  description = "NixOS GitHub Actions Runner Configuration for Nixiso ISO Builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    github-nix-ci = {
      url = "github:juspay/github-nix-ci";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, github-nix-ci }: {
    nixosConfigurations.nixiso-runner = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        agenix.nixosModules.default
        ./configuration.nix
        github-nix-ci.nixosModules.default
      ];
    };
  };
}
