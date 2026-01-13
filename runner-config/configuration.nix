{ config, pkgs, lib, ... }:

{
  # LXC container configuration
  boot.isContainer = true;

  # System architecture
  nixpkgs.hostPlatform = "x86_64-linux";

  # Allow unfree packages (needed for some build tools)
  nixpkgs.config.allowUnfree = true;

  # Hostname
  networking.hostName = "nixiso-runner";

  # Disable systemd-resolved for LXC containers (they use host resolv.conf)
  services.resolved.enable = lib.mkForce false;

  # Timezone
  time.timeZone = "America/Chicago";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings optimized for ISO builds
  nix = {
    settings = {
      # Enable flakes
      experimental-features = [ "nix-command" "flakes" ];

      # Binary caches for faster builds
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://cache.numtide.com"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];

      # Optimize store automatically
      auto-optimise-store = true;

      # Allow more parallel builds
      max-jobs = "auto";
      cores = 0;  # Use all available cores

      # Build settings
      sandbox = true;
      keep-outputs = false;
      keep-derivations = false;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    # Optimize store weekly
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # GitHub Actions Runner Configuration
  # IMPORTANT: You must create /var/lib/secrets/github-runner-token before enabling
  services.github-nix-ci = {
    personalRunners = {
      "fransole/nixiso" = {
        num = 1;  # Number of concurrent runners
        tokenFile = /var/lib/secrets/github-runner-token;  # Use path type, not string
      };
    };

    # Additional packages available to all runners
    runnerSettings.extraPackages = with pkgs; [
      # Add any extra packages needed for builds
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # Essential tools
    git
    curl
    wget
    vim
    htop
    tmux

    # Build tools
    gnumake
    gcc
    binutils

    # Nix tools
    nix-output-monitor  # Better build output
    nix-tree           # Explore dependencies

    # Monitoring
    btop
    ncdu  # Disk usage analyzer
  ];

  # Enable SSH for remote management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Create runner management user
  users.users.runner = {
    isNormalUser = true;
    description = "GitHub Actions Runner Manager";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
      # "ssh-ed25519 AAAA... user@host"
    ];
  };

  # Passwordless sudo for wheel group (for runner management)
  security.sudo.wheelNeedsPassword = false;

  # Systemd service to ensure secrets directory exists
  systemd.services.ensure-runner-secrets = {
    description = "Ensure runner secrets directory exists";
    wantedBy = [ "multi-user.target" ];
    before = [ "github-nix-ci-nixiso-builder.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/secrets
      chmod 700 /var/lib/secrets

      # Check if token file exists
      if [ ! -f /var/lib/secrets/github-runner-token ]; then
        echo "WARNING: /var/lib/secrets/github-runner-token does not exist!"
        echo "Please create this file with your GitHub token before starting the runner."
        echo "Run: echo 'YOUR_GITHUB_TOKEN' | sudo tee /var/lib/secrets/github-runner-token"
        echo "Then: sudo chmod 600 /var/lib/secrets/github-runner-token"
      fi
    '';
  };

  # Monitoring: Log disk usage warnings
  systemd.services.disk-usage-monitor = {
    description = "Monitor disk usage and warn if high";
    serviceConfig.Type = "oneshot";
    script = ''
      USAGE=$(${pkgs.coreutils}/bin/df -h / | ${pkgs.gawk}/bin/awk 'NR==2 {print $5}' | sed 's/%//')
      if [ "$USAGE" -gt 80 ]; then
        echo "WARNING: Disk usage is at $USAGE%"
        echo "Consider running: nix-collect-garbage -d"
      fi
    '';
  };

  systemd.timers.disk-usage-monitor = {
    description = "Check disk usage daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Clean up old runner logs
  systemd.services.cleanup-runner-logs = {
    description = "Clean up old GitHub runner logs";
    serviceConfig.Type = "oneshot";
    script = ''
      if [ -d /var/lib/github-nix-ci ]; then
        find /var/lib/github-nix-ci -name "*.log" -mtime +7 -delete
        echo "Cleaned up logs older than 7 days"
      fi
    '';
  };

  systemd.timers.cleanup-runner-logs = {
    description = "Clean up runner logs weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Firewall configuration (minimal for LXC)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH only
  };

  # System state version
  system.stateVersion = "24.11";
}
