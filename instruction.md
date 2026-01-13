# Self-Hosted GitHub Runner Setup for Nixiso

This guide will help you set up a self-hosted GitHub Actions runner on your NixOS system to build the ISO images automatically.

## Prerequisites

### System Requirements

**Minimum:**
- 2 CPU cores
- 8GB RAM
- 50GB free disk space
- NixOS with flakes enabled

**Recommended:**
- 4+ CPU cores
- 16GB RAM
- 100GB SSD storage
- Fast internet connection

**Expected Build Times:**
- First build: 60-90 minutes (downloads and builds all dependencies)
- Subsequent builds: 20-40 minutes (with Nix cache)

---

## Setup Methods

You have two options for setting up the runner:

### Option 1: Using github-nix-ci Module (Recommended)

This is the easiest and most NixOS-native way to set up GitHub runners.

#### Step 1: Generate GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Configure token:
   - **Token name**: `nixiso-runner`
   - **Expiration**: 90 days (or custom)
   - **Repository access**: Select "Only select repositories" → Choose `nixiso`
   - **Permissions**:
     - Actions: Read and write
     - Contents: Read
     - Metadata: Read (automatically included)
4. Click "Generate token" and copy the token value

#### Step 2: Store Token Securely

Create a secure location for the token:

```bash
sudo mkdir -p /var/lib/secrets
echo "YOUR_GITHUB_TOKEN_HERE" | sudo tee /var/lib/secrets/github-runner-token
sudo chmod 600 /var/lib/secrets/github-runner-token
sudo chown root:root /var/lib/secrets/github-runner-token
```

#### Step 3: Add github-nix-ci to Your Flake

Add to your system's `flake.nix` inputs:

```nix
inputs.github-nix-ci.url = "github:juspay/github-nix-ci";
```

#### Step 4: Configure Runner in configuration.nix

Add this to your NixOS configuration:

```nix
{ inputs, ... }: {
  imports = [
    inputs.github-nix-ci.nixosModules.default
  ];

  services.github-nix-ci = {
    age.secretsDir = "/var/lib/secrets";

    runners.nixiso-builder = {
      owner = "fransole";  # Your GitHub username
      repo = "nixiso";
      num = 1;
      tokenFile = "/var/lib/secrets/github-runner-token";
      labels = [ "self-hosted" "nixos" "x86_64-linux" ];
    };
  };
}
```

#### Step 5: Rebuild Your System

```bash
sudo nixos-rebuild switch
```

#### Step 6: Verify Runner is Active

1. Go to your GitHub repository: `https://github.com/fransole/nixiso`
2. Navigate to Settings → Actions → Runners
3. You should see your runner listed as "Idle" with a green dot

---

### Option 2: Manual Setup (Alternative)

If you prefer manual setup or the github-nix-ci module doesn't work for you:

#### Step 1: Navigate to Repository Settings

1. Go to `https://github.com/fransole/nixiso`
2. Click Settings → Actions → Runners
3. Click "New self-hosted runner"
4. Select Linux as OS and x86_64 as architecture

#### Step 2: Download and Install Runner

Follow the commands shown on GitHub, but adapt for NixOS:

```bash
# Create runner directory
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download the runner (check GitHub for latest version)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure the runner (use the token from GitHub page)
./config.sh --url https://github.com/fransole/nixiso --token YOUR_TOKEN_HERE

# Install as systemd service
sudo ./svc.sh install
sudo ./svc.sh start
```

#### Step 3: Verify Runner

Check status:
```bash
sudo ./svc.sh status
```

Go to GitHub Settings → Actions → Runners and verify it shows as "Idle"

---

### Option 3: Containerized Deployment (Homelab/Server)

Running the GitHub runner in containers provides isolation, resource management, and easier maintenance. This is ideal for homelab servers running Proxmox, Docker, or other container platforms.

#### Option 3A: Docker Container

Run the GitHub runner in a Docker container with Nix installed.

##### Step 1: Create Dockerfile

Create a `nixos-runner.Dockerfile`:

```dockerfile
FROM nixos/nix:latest

# Install systemd and basic tools
RUN nix-env -iA nixpkgs.systemd nixpkgs.git nixpkgs.curl nixpkgs.sudo

# Enable flakes
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Add binary caches
RUN echo "substituters = https://cache.nixos.org https://nix-community.cachix.org https://cache.numtide.com" >> /etc/nix/nix.conf && \
    echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" >> /etc/nix/nix.conf

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Download and install GitHub Actions runner
WORKDIR /home/runner
ARG RUNNER_VERSION=2.311.0
RUN curl -o actions-runner.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf actions-runner.tar.gz && \
    rm actions-runner.tar.gz && \
    chown -R runner:runner /home/runner

USER runner
WORKDIR /home/runner

# Entry point will configure and start runner
COPY docker-entrypoint.sh /home/runner/entrypoint.sh
ENTRYPOINT ["/home/runner/entrypoint.sh"]
```

##### Step 2: Create Entry Point Script

Create `docker-entrypoint.sh`:

```bash
#!/bin/bash
set -e

# Configure runner if not already configured
if [ ! -f .runner ]; then
    ./config.sh \
        --url https://github.com/${GITHUB_OWNER}/${GITHUB_REPO} \
        --token ${GITHUB_TOKEN} \
        --labels docker,nixos,x86_64-linux \
        --unattended \
        --replace
fi

# Cleanup function
cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token ${GITHUB_TOKEN}
}
trap cleanup EXIT

# Start runner
./run.sh
```

Make it executable:
```bash
chmod +x docker-entrypoint.sh
```

##### Step 3: Build Docker Image

```bash
docker build -f nixos-runner.Dockerfile -t nixos-github-runner:latest .
```

##### Step 4: Run Container

```bash
docker run -d \
  --name nixiso-runner \
  --restart unless-stopped \
  -e GITHUB_OWNER=fransole \
  -e GITHUB_REPO=nixiso \
  -e GITHUB_TOKEN=your_github_token_here \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v nixos-runner-work:/home/runner/_work \
  -v nix-store:/nix \
  nixos-github-runner:latest
```

##### Step 5: Monitor Container

```bash
# View logs
docker logs -f nixiso-runner

# Check runner status
docker exec nixiso-runner ps aux

# Verify on GitHub
# Navigate to Settings → Actions → Runners
```

##### Docker Compose (Alternative)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  nixiso-runner:
    build:
      context: .
      dockerfile: nixos-runner.Dockerfile
    container_name: nixiso-runner
    restart: unless-stopped
    environment:
      - GITHUB_OWNER=fransole
      - GITHUB_REPO=nixiso
      - GITHUB_TOKEN=${GITHUB_TOKEN}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - runner-work:/home/runner/_work
      - nix-store:/nix
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 16G
        reservations:
          cpus: '2'
          memory: 8G

volumes:
  runner-work:
  nix-store:
```

Start with:
```bash
export GITHUB_TOKEN=your_token_here
docker-compose up -d
```

---

#### Option 3B: LXC Container (Proxmox/Incus)

LXC containers provide better performance than Docker for long-running services.

##### Proxmox Setup

**Step 1: Create NixOS LXC Container**

Download NixOS LXC template:
```bash
# On Proxmox host
cd /var/lib/vz/template/cache
wget https://hydra.nixos.org/job/nixos/release-24.11/nixos.lxdContainerImage.x86_64-linux/latest/download-by-type/file/tarball
mv tarball nixos-24.11-lxc.tar.xz
```

Create container via Proxmox UI:
- CT ID: 100 (or your choice)
- Template: nixos-24.11-lxc.tar.xz
- Hostname: nixiso-runner
- Unprivileged container: Yes
- CPU: 4 cores
- Memory: 8192 MB (16384 recommended)
- Swap: 4096 MB
- Disk: 100 GB
- Network: Bridge to your network

**Step 2: Configure Container**

Start and enter container:
```bash
pct start 100
pct enter 100
```

Inside container, create `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [ <nixpkgs/nixos/modules/virtualisation/lxc-container.nix> ];

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Binary caches
  nix.settings = {
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
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings.auto-optimise-store = true;

  # Enable SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  # Networking
  networking.hostName = "nixiso-runner";
  networking.useNetworkd = true;

  # System packages
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
  ];

  # Create runner user
  users.users.runner = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
    ];
  };

  # Passwordless sudo for runner
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.11";
}
```

Apply configuration:
```bash
nixos-rebuild switch
```

**Step 3: Install GitHub Runner**

As runner user:
```bash
su - runner
mkdir ~/actions-runner && cd ~/actions-runner

# Download runner
curl -o actions-runner.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

tar xzf actions-runner.tar.gz
rm actions-runner.tar.gz

# Configure (get token from GitHub Settings → Actions → Runners → New)
./config.sh \
  --url https://github.com/fransole/nixiso \
  --token YOUR_GITHUB_TOKEN \
  --labels lxc,nixos,x86_64-linux \
  --unattended
```

**Step 4: Create Systemd Service**

Create `/etc/systemd/system/github-runner.service`:

```ini
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/home/runner/actions-runner
ExecStart=/home/runner/actions-runner/run.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-runner
sudo systemctl start github-runner
sudo systemctl status github-runner
```

##### Incus/LXD Setup

**Step 1: Launch NixOS Container**

```bash
# Add NixOS image
incus image copy images:nixos/24.11 local: --alias nixos

# Launch container
incus launch nixos nixiso-runner -c limits.cpu=4 -c limits.memory=16GB

# Access container
incus exec nixiso-runner -- bash
```

**Step 2: Configure (same as Proxmox)**

Follow Step 2-4 from Proxmox setup above.

---

#### Container Resource Recommendations

**For Docker:**
- CPU: 2-4 cores minimum, 4-8 recommended
- Memory: 8GB minimum, 16GB recommended
- Storage: 100GB for Nix store and build artifacts
- Enable nested virtualization if using KVM features

**For LXC:**
- CPU: 4 cores minimum, 8 recommended
- Memory: 8GB minimum, 16GB recommended
- Storage: 100GB disk space
- Enable nesting: `pct set <CTID> -features nesting=1` (Proxmox)

**Storage Volumes:**
- `/nix` - Nix store (persistent, 50GB+)
- `/home/runner/_work` - Build workspace (persistent, 30GB+)
- Consider using ZFS datasets or separate volumes for easy management

---

#### Container Security Considerations

1. **Isolation**: Containers provide process isolation from host
2. **Resource Limits**: Set CPU and memory limits to prevent resource exhaustion
3. **Token Security**: Use environment variables or secrets management, never hardcode
4. **Updates**: Regularly rebuild container images with updated packages
5. **Monitoring**: Set up logging and resource monitoring
6. **Backups**: Back up `/nix` and runner configuration if using stateful setup

---

#### Container Networking

**Docker:**
- Bridge mode (default) works for most cases
- Expose Docker socket for Docker-in-Docker builds
- Consider using macvlan for direct network access

**LXC:**
- Bridge to host network (default)
- Static IP recommended for easier management
- Open firewall ports if needed (usually not required for outbound)

---

## Post-Setup Configuration

### Binary Cache Configuration

To speed up builds, ensure your runner has access to Nix binary caches:

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://cache.numtide.com"
  ];
  trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
  experimental-features = [ "nix-command" "flakes" ];
};
```

### Disk Space Management

ISO builds can consume significant disk space. Set up automatic garbage collection:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 7d";
};

nix.settings.auto-optimise-store = true;
```

### Runner Labels

The workflow is configured to use `runs-on: self-hosted`. Ensure your runner has the appropriate labels:
- `self-hosted` (automatically added)
- `nixos` (optional, for clarity)
- `x86_64-linux` (optional, for clarity)

---

## Testing the Setup

### Trigger a Manual Build

1. Go to your repository on GitHub
2. Click Actions → Build NixOS Live ISO
3. Click "Run workflow" → Select branch "main"
4. Check "upload_artifact" if desired
5. Click "Run workflow"

### Monitor Build Progress

1. Click on the running workflow
2. Click on "build-iso" job
3. Watch the build logs

### Expected Output

- Build time: 20-60 minutes
- ISO size: 2-3GB
- Result: ISO file uploaded as artifact or released

---

## Troubleshooting

### Runner Not Appearing in GitHub

**Check runner status:**
```bash
# For github-nix-ci
sudo systemctl status github-nix-ci-nixiso-builder

# For manual setup
cd ~/actions-runner && sudo ./svc.sh status
```

**Check logs:**
```bash
# For github-nix-ci
sudo journalctl -u github-nix-ci-nixiso-builder -f

# For manual setup
cd ~/actions-runner && cat _diag/Worker_*.log
```

### Build Fails with "out of memory"

Increase available RAM or add swap:

```nix
swapDevices = [{
  device = "/var/swapfile";
  size = 8192;  # 8GB swap
}];
```

### Build Fails with "disk space"

Clean up Nix store:

```bash
nix-collect-garbage -d
sudo nix-collect-garbage -d
```

### Token Expired

Regenerate token on GitHub and update:

```bash
echo "NEW_TOKEN_HERE" | sudo tee /var/lib/secrets/github-runner-token
sudo systemctl restart github-nix-ci-nixiso-builder
```

---

## Security Considerations

### Token Security

- Store tokens in `/var/lib/secrets/` with `600` permissions
- Use fine-grained tokens with minimal permissions
- Set expiration dates (90 days recommended)
- Rotate tokens regularly

### Runner Isolation

- Run on a dedicated machine or VM if possible
- Don't run on your primary workstation
- Monitor resource usage
- Review workflow logs regularly

### Network Security

- Ensure runner has outbound internet access
- Firewall isn't required for outbound connections
- No inbound connections needed

---

## Maintenance

### Regular Tasks

**Weekly:**
- Check runner is active in GitHub Settings
- Monitor disk space usage
- Review build logs for errors

**Monthly:**
- Update flake inputs: `nix flake update`
- Test a manual build
- Check token expiration

**Quarterly:**
- Review and update NixOS system
- Regenerate GitHub token
- Clean up old artifacts/releases

### Updating the Runner

**For github-nix-ci:**
```bash
# Update flake input
nix flake lock --update-input github-nix-ci

# Rebuild
sudo nixos-rebuild switch
```

**For manual setup:**
```bash
cd ~/actions-runner
sudo ./svc.sh stop
./config.sh remove
# Download new version and reconfigure
sudo ./svc.sh install
sudo ./svc.sh start
```

---

## Additional Resources

- [github-nix-ci Documentation](https://github.com/juspay/github-nix-ci)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)

---

## Need Help?

If you encounter issues:
1. Check the troubleshooting section above
2. Review runner logs
3. Open an issue in the nixiso repository
4. Check NixOS Discourse or Matrix for community help
