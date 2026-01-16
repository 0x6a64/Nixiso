{
  description = "NixOS Live Boot ISO with GNOME and Development Tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # Deduplicate nixpkgs - use our nixpkgs for llm-agents too
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, llm-agents }: {
    # NixOS ISO configuration
    nixosConfigurations.live-iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inputs = { inherit nixpkgs llm-agents; }; };
      modules = [
        ({ modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
            ./iso-configuration.nix
          ];
        })
      ];
    };

    # Development shell for working on this flake
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      name = "nixiso-dev";
      packages = with nixpkgs.legacyPackages.x86_64-linux; [
        alejandra  # Nix formatter
        nil        # Nix language server
      ];
      shellHook = ''
        echo "Nixiso development environment"
        echo ""
        echo "Commands:"
        echo "  nix flake check                                                    - Validate flake"
        echo "  nix build .#nixosConfigurations.live-iso.config.system.build.isoImage - Build ISO"
      '';
    };
  };
}
