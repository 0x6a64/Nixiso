# Nixiso GitHub Actions Runner Configuration

Self-hosted GitHub Actions runner for building Nixiso ISOs. Deploy this inside a NixOS LXC container on Proxmox. Lean, auto-updating, and self-maintaining.

## Overview

This flake configures a NixOS system (already running in an LXC container) with:
- GitHub Actions runner via github-nix-ci
- Automatic weekly updates and garbage collection
- Optimized for ISO builds with minimal resources
- Binary caches pre-configured

## Prerequisites

- NixOS LXC container already created and running on Proxmox
- GitHub Personal Access Token (fine-grained)

## Setup

### 1. Create NixOS LXC Container on Proxmox

**Download NixOS template (on Proxmox host):**
```bash
cd /var/lib/vz/template/cache
wget https://hydra.nixos.org/job/nixos/release-24.11/nixos.lxdContainerImage.x86_64-linux/latest/download-by-type/file/tarball -O nixos-24.11-lxc.tar.xz
```

**Create container:**
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

pct start 100
pct enter 100
```

### 2. Deploy Runner Configuration

**Inside the container, generate GitHub token:**
1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Create token:
   - Repository: `nixiso`
   - Permissions: Actions (R/W), Contents (Read), Metadata (Read)
   - Expiration: 90 days

**Store token:**
```bash
mkdir -p /var/lib/secrets
echo "YOUR_GITHUB_TOKEN_HERE" > /var/lib/secrets/github-runner-token
chmod 600 /var/lib/secrets/github-runner-token
```

**Deploy this flake:**
```bash
cd /etc/nixos

# Copy flake.nix to /etc/nixos/flake.nix
# Edit flake.nix and update the owner and repo fields

nixos-rebuild switch --flake .#nixiso-runner
```

### 3. Verify

Check GitHub: Settings → Actions → Runners

Runner should appear as "Idle" with green status.

## What's Configured

- **Auto-updating**: Weekly system updates (nixos-unstable)
- **Auto-cleanup**: Weekly garbage collection (>7 days)
- **Storage optimization**: Automatic Nix store deduplication
- **Binary caches**: Pre-configured for fast builds
- **SSH**: Enabled for remote management
- **Resources**: Minimal - 4 cores, 6GB RAM, 60GB disk

## Maintenance

### Automatic (no action needed)
- Weekly garbage collection
- Weekly system updates
- Continuous storage optimization
- Automatic runner updates

### Manual Commands

**Check runner:**
```bash
systemctl status github-nix-ci-nixiso-builder
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

**Disk usage:**
```bash
df -h
du -sh /nix/store
nix-collect-garbage -d
nix-store --optimise
```

## Troubleshooting

**Runner not showing:**
```bash
systemctl status github-nix-ci-nixiso-builder
journalctl -u github-nix-ci-nixiso-builder -n 50
```

**Out of space:**
```bash
nix-collect-garbage -d
nix-store --optimise
# Resize from Proxmox: pct resize 100 rootfs +20G
```

**Token expired:**
```bash
echo "NEW_TOKEN" > /var/lib/secrets/github-runner-token
chmod 600 /var/lib/secrets/github-runner-token
systemctl restart github-nix-ci-nixiso-builder
```

## Customization

**Multiple runners:**
```nix
runners.nixiso-builder = {
  num = 2;  # Run 2 concurrent
  # ...
};
```

**Different repo:**
```nix
owner = "your-username";
repo = "your-repo";
```

**More aggressive cleanup:**
```nix
nix.gc = {
  dates = "daily";
  options = "--delete-older-than 3d";
};
```

## Resources

- **CPU**: 2-4 cores
- **Memory**: 6GB (8GB recommended)
- **Storage**: 60GB
- **Swap**: 2GB

## Links

- [github-nix-ci](https://github.com/juspay/github-nix-ci)
- [Proxmox LXC](https://pve.proxmox.com/wiki/Linux_Container)
