{
  description = "Nixiso GitHub Actions Runner - Lean and Auto-Updating";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    github-nix-ci.url = "github:juspay/github-nix-ci";
  };

  outputs = { self, nixpkgs, github-nix-ci }: {
    nixosConfigurations.nixiso-runner = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import github-nix-ci module
        github-nix-ci.nixosModules.default

        # Main configuration
        ({ config, pkgs, ... }: {

          # === Nix Configuration ===
          nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];

            # Binary caches for faster builds
            substituters = [
              "https://cache.nixos.org"
              "https://nix-community.cachix.org"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];

            # Keep system lean
            auto-optimise-store = true;
          };

          # Automatic garbage collection - removes old builds weekly
          nix.gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
          };

          # === Auto-Update System ===
          system.autoUpgrade = {
            enable = true;
            dates = "weekly";
            flake = "/etc/nixos";
            allowReboot = false;
          };

          # === GitHub Runner Configuration ===
          services.github-nix-ci = {
            age.secretsDir = "/var/lib/secrets";

            runners.nixiso-builder = {
              owner = "fransole";  # ← CHANGE THIS to your GitHub username
              repo = "nixiso";      # ← CHANGE THIS to your repository name
              num = 1;
              tokenFile = "/var/lib/secrets/github-runner-token";
              labels = [ "self-hosted" "nixos" "lxc" "x86_64-linux" ];
            };
          };

          # === System Configuration ===
          networking = {
            hostName = "nixiso-runner";
            useNetworkd = true;
          };

          # SSH for remote management
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          # Minimal essential packages
          environment.systemPackages = with pkgs; [
            git
            curl
            vim
            htop
          ];

          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
