# NixOS GitHub Actions Runner Configuration

Complete, production-ready NixOS configuration for running GitHub Actions runners in LXC containers using github-nix-ci.

## Overview

This configuration provides:
- GitHub Actions runner via github-nix-ci
- Optimized Nix settings for ISO builds
- Automatic garbage collection and store optimization
- Monitoring and maintenance systemd services
- SSH access for management
- Binary cache configuration for fast builds

## Prerequisites

- NixOS LXC container (Proxmox, Incus, or LXD)
- GitHub Personal Access Token (fine-grained)
- SSH access to the container

## Quick Start

### 1. Deploy to LXC Container

**On Proxmox:**
```bash
# Download NixOS LXC template (on Proxmox host)
cd /var/lib/vz/template/cache
wget https://hydra.nixos.org/job/nixos/release-24.11/nixos.lxdContainerImage.x86_64-linux/latest/download-by-type/file/tarball
mv tarball nixos-24.11-lxc.tar.xz

# Create container via Proxmox UI:
# - CT ID: 100 (or your choice)
# - Template: nixos-24.11-lxc.tar.xz
# - Hostname: nixiso-runner
# - Unprivileged: Yes
# - CPU: 4-8 cores
# - Memory: 8-16GB
# - Disk: 100GB
# - Network: Bridge to your network

# Start and enter container
pct start 100
pct enter 100
```

**On Incus/LXD:**
```bash
incus image copy images:nixos/24.11 local: --alias nixos
incus launch nixos nixiso-runner \
  -c limits.cpu=4 \
  -c limits.memory=16GB \
  -c boot.autostart=true
incus exec nixiso-runner -- bash
```

### 2. Initial Container Setup

Inside the container:

```bash
# Clone this configuration
cd /etc/nixos
git init
git remote add origin https://github.com/fransole/nixiso.git
git fetch origin
git checkout origin/main -- runner-config
cd runner-config

# Or manually copy files
# Copy flake.nix, configuration.nix, and this README to /etc/nixos/
```

### 3. Generate GitHub Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Configure:
   - Name: `nixiso-runner`
   - Expiration: 90 days (recommended)
   - Repository access: Only `fransole/nixiso`
   - Permissions:
     - Actions: Read and write
     - Contents: Read
     - Metadata: Read (auto-included)
4. Generate and copy the token

### 4. Configure Secrets

```bash
# Create secrets directory
sudo mkdir -p /var/lib/secrets
sudo chmod 700 /var/lib/secrets

# Store GitHub token
echo "ghp_YOUR_TOKEN_HERE" | sudo tee /var/lib/secrets/github-runner-token
sudo chmod 600 /var/lib/secrets/github-runner-token
sudo chown root:root /var/lib/secrets/github-runner-token
```

### 5. Configure SSH Access (Optional)

Edit `configuration.nix` and add your SSH public key:

```nix
users.users.runner = {
  # ... existing config ...
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3Nza... your-key-here"
  ];
};
```

### 6. Deploy Configuration

```bash
# Initial build and switch
sudo nixos-rebuild switch --flake .#nixiso-runner

# Or if using the flake from /etc/nixos/runner-config:
cd /etc/nixos/runner-config
sudo nixos-rebuild switch --flake .#nixiso-runner
```

### 7. Verify Runner

Check runner status:
```bash
# Check systemd service
sudo systemctl status github-nix-ci-nixiso-builder

# View logs
sudo journalctl -u github-nix-ci-nixiso-builder -f

# Check on GitHub
# Go to: https://github.com/fransole/nixiso/settings/actions/runners
# Your runner should appear as "Idle" with a green dot
```

## Configuration Details

### Resources

**Minimum:**
- CPU: 4 cores
- Memory: 8GB
- Storage: 100GB

**Recommended:**
- CPU: 8 cores
- Memory: 16GB
- Storage: 200GB

### Nix Settings

- **Flakes**: Enabled
- **Binary caches**: cache.nixos.org, nix-community, numtide
- **Garbage collection**: Weekly, delete >7 days old
- **Store optimization**: Weekly, automatic deduplication
- **Max jobs**: Auto (uses all cores)
- **Sandbox**: Enabled for security

### Systemd Services

**github-nix-ci-nixiso-builder**
- Main runner service
- Auto-restart on failure
- 15-minute timeout for long builds

**ensure-runner-secrets**
- Ensures secrets directory exists
- Warns if token is missing
- Runs before runner starts

**disk-usage-monitor**
- Checks disk usage daily
- Warns at >80% usage
- Suggests cleanup commands

**cleanup-runner-logs**
- Removes logs >7 days old
- Runs weekly
- Prevents log buildup

## Management

### Check Runner Status

```bash
# Service status
sudo systemctl status github-nix-ci-nixiso-builder

# View logs (live)
sudo journalctl -u github-nix-ci-nixiso-builder -f

# View logs (last 100 lines)
sudo journalctl -u github-nix-ci-nixiso-builder -n 100
```

### Restart Runner

```bash
sudo systemctl restart github-nix-ci-nixiso-builder
```

### Update Configuration

```bash
cd /etc/nixos/runner-config
# Edit configuration.nix as needed
sudo nixos-rebuild switch --flake .#nixiso-runner
```

### Update Flake Inputs

```bash
cd /etc/nixos/runner-config
nix flake update
sudo nixos-rebuild switch --flake .#nixiso-runner
```

### Disk Space Management

```bash
# Check disk usage
df -h

# Clean up old generations
sudo nix-collect-garbage -d

# Optimize store (deduplicate)
sudo nix-store --optimise

# Check what's using space
ncdu /nix/store
```

### Rotate GitHub Token

```bash
# Generate new token on GitHub
# Update token file
echo "ghp_NEW_TOKEN_HERE" | sudo tee /var/lib/secrets/github-runner-token
sudo chmod 600 /var/lib/secrets/github-runner-token

# Restart runner to use new token
sudo systemctl restart github-nix-ci-nixiso-builder
```

## Monitoring

### System Resources

```bash
# CPU and memory
btop

# Disk usage
ncdu /

# Network
ip addr show
```

### Build Logs

```bash
# Follow current build
sudo journalctl -u github-nix-ci-nixiso-builder -f

# Search for errors
sudo journalctl -u github-nix-ci-nixiso-builder | grep -i error

# Export logs
sudo journalctl -u github-nix-ci-nixiso-builder --since "1 hour ago" > runner.log
```

### GitHub Actions

Check builds on GitHub:
- Repository → Actions tab
- View workflow runs
- Download ISO artifacts

## Troubleshooting

### Runner Not Starting

**Check token file exists:**
```bash
ls -la /var/lib/secrets/github-runner-token
```

**Check service logs:**
```bash
sudo journalctl -u github-nix-ci-nixiso-builder -n 50
```

**Verify token is valid:**
- Go to GitHub → Settings → Developer settings → Personal access tokens
- Check expiration date
- Verify repository access

### Build Failures

**Check disk space:**
```bash
df -h
sudo nix-collect-garbage -d
```

**Check memory:**
```bash
free -h
# If low, increase container memory or add swap
```

**View build logs:**
```bash
sudo journalctl -u github-nix-ci-nixiso-builder -n 200
```

### Runner Shows Offline on GitHub

**Restart service:**
```bash
sudo systemctl restart github-nix-ci-nixiso-builder
```

**Check network connectivity:**
```bash
ping github.com
curl -I https://api.github.com
```

**Re-register runner:**
```bash
# Delete old runner on GitHub
# Restart service (it will auto-register)
sudo systemctl restart github-nix-ci-nixiso-builder
```

## Customization

### Change Runner Labels

Edit `configuration.nix`:
```nix
services.github-nix-ci.runners.nixiso-builder = {
  labels = [ "self-hosted" "nixos" "lxc" "x86_64-linux" "my-label" ];
};
```

### Run Multiple Runners

Edit `configuration.nix`:
```nix
services.github-nix-ci.runners.nixiso-builder = {
  num = 2;  # Run 2 concurrent runners
};
```

### Add Extra Packages

Edit `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  # Add your packages here
  docker
  podman
];
```

### Adjust Garbage Collection

Edit `configuration.nix`:
```nix
nix.gc = {
  automatic = true;
  dates = "daily";  # Run daily instead of weekly
  options = "--delete-older-than 3d";  # Keep 3 days instead of 7
};
```

## Security

### Recommendations

1. **Use fine-grained tokens** with minimal permissions
2. **Rotate tokens regularly** (every 90 days recommended)
3. **Use SSH key authentication** (disable password auth)
4. **Keep NixOS updated** regularly
5. **Monitor runner logs** for suspicious activity
6. **Limit network access** if possible (firewall rules)

### Token Security

- Token stored in `/var/lib/secrets/` with 600 permissions
- Only root can read
- Not exposed in logs or process list
- Not committed to git

## Backup

### Important Files to Backup

- `/var/lib/secrets/github-runner-token` - GitHub token
- `/etc/nixos/runner-config/` - Configuration files
- `/root/.ssh/` - SSH keys (if used)

### Container Snapshots

**Proxmox:**
```bash
# Create snapshot
pct snapshot 100 pre-update

# Rollback if needed
pct rollback 100 pre-update
```

**Incus:**
```bash
# Create snapshot
incus snapshot nixiso-runner pre-update

# Restore if needed
incus restore nixiso-runner pre-update
```

## Updates

### Update NixOS

```bash
cd /etc/nixos/runner-config
nix flake update
sudo nixos-rebuild switch --flake .#nixiso-runner
```

### Update github-nix-ci

```bash
cd /etc/nixos/runner-config
nix flake lock --update-input github-nix-ci
sudo nixos-rebuild switch --flake .#nixiso-runner
```

## Performance Tuning

### For Heavy Workloads

Edit `configuration.nix`:

```nix
nix.settings = {
  max-jobs = 8;  # Limit concurrent builds
  cores = 2;     # Cores per job (8 jobs × 2 cores = 16 cores used)

  # Increase build timeout
  timeout = 86400;  # 24 hours
};
```

### For Resource-Constrained Systems

```nix
nix.settings = {
  max-jobs = 2;  # Fewer concurrent builds
  cores = 4;     # More cores per job
};

# Reduce garbage collection frequency
nix.gc.dates = "monthly";
```

## Support

- **Issues**: https://github.com/fransole/nixiso/issues
- **Discussions**: https://github.com/fransole/nixiso/discussions
- **github-nix-ci**: https://github.com/juspay/github-nix-ci

## License

This configuration is part of the Nixiso project. See main repository for license details.
