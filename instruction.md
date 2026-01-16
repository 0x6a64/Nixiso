# GitHub Actions Runner for Nixiso - Proxmox LXC Setup

This guide sets up a self-hosted GitHub Actions runner in a Proxmox LXC container running NixOS with github-nix-ci. Just drop in a single flake.nix and you're ready to go.

## Quick Start

1. Create Proxmox LXC container with NixOS
2. Drop in the flake.nix provided below
3. Add your GitHub token
4. Run `nixos-rebuild switch --flake .`
5. Done - runner stays updated and lean automatically

---

## Step 1: Create LXC Container in Proxmox

### Download NixOS Template

On your Proxmox host:

```bash
cd /var/lib/vz/template/cache
wget https://hydra.nixos.org/job/nixos/release-24.11/nixos.lxdContainerImage.x86_64-linux/latest/download-by-type/file/tarball -O nixos-24.11-lxc.tar.xz
```

### Create Container

**Via Proxmox Web UI:**

1. Click "Create CT"
2. **General:**
   - CT ID: 100 (or your choice)
   - Hostname: `nixiso-runner`
   - Unprivileged: ✓ Yes
   - Nesting: ✓ Yes
3. **Template:** nixos-24.11-lxc.tar.xz
4. **Resources:**
   - CPU: 4 cores
   - Memory: 6144 MB
   - Swap: 2048 MB
   - Disk: 60 GB
5. **Network:** Bridge vmbr0, DHCP
6. Click "Finish"

**Or via CLI:**

```bash
pct create 100 local:vztmpl/nixos-24.11-lxc.tar.xz \
  --hostname nixiso-runner \
  --memory 6144 \
  --swap 2048 \
  --cores 4 \
  --rootfs local-lvm:60 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1
```

### Start Container

```bash
pct start 100
pct enter 100
```

---

## Step 2: Configure the Runner

### Generate GitHub Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Generate new token:
   - **Name**: `nixiso-runner`
   - **Expiration**: 90 days
   - **Repository**: Only `nixiso`
   - **Permissions**: Actions (Read/Write), Contents (Read), Metadata (Read)
3. Copy the token

### Store Token

Inside the container:

```bash
mkdir -p /var/lib/secrets
echo "YOUR_GITHUB_TOKEN_HERE" > /var/lib/secrets/github-runner-token
chmod 600 /var/lib/secrets/github-runner-token
```

### Create Flake Configuration

Create `/etc/nixos/flake.nix` with the following content. **Update the `owner` and `repo` fields** to match your GitHub username and repository:

```nix
{
  description = "Nixiso GitHub Actions Runner - Lean and Auto-Updating";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    github-nix-ci.url = "github:juspay/github-nix-ci";
  };

  outputs = { self, nixpkgs, github-nix-ci }: {
    nixosConfigurations.nixiso-runner = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import LXC container base
        "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"

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
```

### Deploy

```bash
cd /etc/nixos
nixos-rebuild switch --flake .#nixiso-runner
```

The runner will start automatically.

---

## Step 3: Verify

Go to your GitHub repository:
- Settings → Actions → Runners
- You should see `nixiso-runner-nixiso-builder-1` listed as "Idle" with a green dot

---

## Maintenance

### Automatic (No Action Needed)

The system maintains itself:
- **Weekly**: Garbage collection, system updates
- **Continuous**: Storage optimization, runner updates

### Manual Tasks

**Check runner status:**
```bash
systemctl status github-nix-ci-nixiso-builder
```

**View logs:**
```bash
journalctl -u github-nix-ci-nixiso-builder -f
```

**Update flake (monthly):**
```bash
cd /etc/nixos
nix flake update
nixos-rebuild switch --flake .#nixiso-runner
```

**Rotate token (every 90 days):**
```bash
echo "NEW_TOKEN" > /var/lib/secrets/github-runner-token
systemctl restart github-nix-ci-nixiso-builder
```

**Check disk usage:**
```bash
df -h
du -sh /nix/store
```

**Manual cleanup if needed:**
```bash
nix-collect-garbage -d
nix-store --optimise
```

---

## Troubleshooting

### Runner not appearing in GitHub

```bash
systemctl status github-nix-ci-nixiso-builder
journalctl -u github-nix-ci-nixiso-builder -n 50
```

### Build failures

```bash
journalctl -u github-nix-ci-nixiso-builder -f
```

### Out of disk space

```bash
# Clean up
nix-collect-garbage -d
nix-store --optimise

# If still low, resize from Proxmox host:
pct resize 100 rootfs +20G
```

### Token expired

```bash
echo "NEW_TOKEN" > /var/lib/secrets/github-runner-token
chmod 600 /var/lib/secrets/github-runner-token
systemctl restart github-nix-ci-nixiso-builder
```

---

## Testing

Trigger a manual build:
1. GitHub repository → Actions
2. Select "Build NixOS Live ISO" workflow
3. Click "Run workflow"
4. Monitor in Actions tab

Expected build time: 15-30 minutes

---

## Backup

```bash
# On Proxmox host - backup container
vzdump 100 --storage local --mode stop

# Restore if needed
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst
```

---

## Resource Requirements

- **CPU**: 2-4 cores
- **Memory**: 6GB (8GB recommended)
- **Storage**: 60GB
- **Swap**: 2GB

Minimal and can run alongside other services.

---

## Security

- Token stored with 600 permissions (root only)
- Fine-grained token with minimal permissions
- Rotate every 90 days
- Unprivileged container for isolation
- No inbound connections required

---

## Resources

- [github-nix-ci](https://github.com/juspay/github-nix-ci)
- [NixOS LXC](https://nixos.wiki/wiki/LXC)
- [Proxmox LXC Docs](https://pve.proxmox.com/wiki/Linux_Container)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
