# GitHub Actions Runner for Nixiso - Proxmox LXC Setup

Set up a self-hosted GitHub Actions runner in a Proxmox LXC container running NixOS with github-nix-ci. Drop in a single flake and you're done.

## Quick Start

1. Create NixOS LXC container on Proxmox
2. Enter container and add GitHub token
3. Copy `runner-config/flake.nix` to `/etc/nixos/flake.nix`
4. Run `nixos-rebuild switch --flake .#nixiso-runner`
5. Done - runner auto-updates and stays lean

---

## Step 1: Create NixOS LXC Container

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

## Step 2: Deploy Runner Configuration

### Generate GitHub Token

1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
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

### Deploy Flake

Copy the `flake.nix` from `runner-config/` to `/etc/nixos/flake.nix` in the container.

The flake is self-contained and includes:
- GitHub runner configuration (github-nix-ci)
- Weekly auto-updates (nixos-unstable)
- Weekly garbage collection (7 day retention)
- Auto storage optimization
- Binary caches for fast builds
- SSH access

**Edit and deploy:**

```bash
cd /etc/nixos

# Edit flake.nix and update these fields:
# - owner: "fransole"  # Your GitHub username
# - repo: "nixiso"      # Your repository

nixos-rebuild switch --flake .#nixiso-runner
```

The runner starts automatically.

---

## Step 3: Verify

Go to GitHub repository: Settings → Actions → Runners

You should see the runner as "Idle" with a green status.

---

## What's Configured

- **NixOS**: nixos-unstable (modern, rolling)
- **Auto-updating**: Weekly system updates
- **Auto-cleanup**: Weekly garbage collection (>7 days old)
- **Storage**: Automatic Nix store deduplication
- **Binary caches**: Pre-configured for fast builds
- **SSH**: Enabled for remote management
- **Resources**: Minimal - 4 cores, 6GB RAM, 60GB disk

---

## Maintenance

### Automatic (No Action Needed)

The system maintains itself:
- Weekly system updates (nixos-unstable)
- Weekly garbage collection
- Continuous storage optimization
- Automatic runner updates

### Manual Commands

**Check runner status:**
```bash
systemctl status github-nix-ci-nixiso-builder
```

**View logs:**
```bash
journalctl -u github-nix-ci-nixiso-builder -f
```

**Update flake inputs (monthly):**
```bash
cd /etc/nixos
nix flake update
nixos-rebuild switch --flake .#nixiso-runner
```

**Rotate GitHub token (every 90 days):**
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

### Runner Not Appearing in GitHub

```bash
systemctl status github-nix-ci-nixiso-builder
journalctl -u github-nix-ci-nixiso-builder -n 50
```

### Build Failures

```bash
journalctl -u github-nix-ci-nixiso-builder -f
```

### Out of Disk Space

```bash
# Clean up
nix-collect-garbage -d
nix-store --optimise

# If still low, resize from Proxmox host:
pct resize 100 rootfs +20G
```

### Token Expired

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

## Customization

### Multiple Runners

Edit `flake.nix`:
```nix
runners.nixiso-builder = {
  num = 2;  # Run 2 concurrent runners
  # ...
};
```

### Different Repository

Edit `flake.nix`:
```nix
owner = "your-username";
repo = "your-repo";
```

### More Aggressive Cleanup

Edit `flake.nix`:
```nix
nix.gc = {
  automatic = true;
  dates = "daily";  # Instead of weekly
  options = "--delete-older-than 3d";  # Instead of 7d
};
```

---

## Container Backup

**Backup:**
```bash
# On Proxmox host
vzdump 100 --storage local --mode stop
```

**Restore:**
```bash
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst
```

---

## Resource Requirements

- **CPU**: 2-4 cores
- **Memory**: 6GB (8GB recommended)
- **Storage**: 60GB
- **Swap**: 2GB

Minimal footprint - can run alongside other services.

---

## Security

- Token stored with 600 permissions (root only)
- Fine-grained token with minimal permissions
- Rotate every 90 days
- Unprivileged container for isolation
- No inbound network connections required

---

## Files

- `runner-config/flake.nix` - Complete runner configuration (deploy to `/etc/nixos/`)
- `runner-config/README.md` - Detailed documentation

---

## Resources

- [github-nix-ci](https://github.com/juspay/github-nix-ci)
- [NixOS LXC](https://nixos.wiki/wiki/LXC)
- [Proxmox LXC Docs](https://pve.proxmox.com/wiki/Linux_Container)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
