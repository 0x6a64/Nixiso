# Nixiso

A NixOS live boot ISO with GNOME desktop, development tools, and CLI utilities. Built automatically with GitHub Actions and self-hosted runners.

## Features

### Desktop Environment
- **GNOME** with dark mode (Stylix + Kanagawa theme)
- Beautiful Kanagawa color scheme throughout the system
- Modern, polished interface with carefully tuned dconf settings
- Auto-login for instant access

### Development Tools
- **Editors**: VSCode, Ghostty terminal
- **Nix Tools**: nixd, nil, alejandra (formatter)
- **AI**: Claude Code
- **Version Control**: git, github-cli
- **Containers**: Docker (rootless), distrobox
- **Languages**: Full Nix development environment

### CLI Utilities
- **Modern replacements**: bat (cat), lsd (ls), ripgrep (grep), gtrash (rm)
- **System monitoring**: btop, fastfetch, nvtop, dysk
- **Shell**: ZSH with Powerlevel10k theme
- **Networking**: nmap, wget, curl, NetworkManager
- **Archives**: p7zip, zip, unzip, xz
- **Utilities**: fzf, jq, tealdeer

### System Features
- Latest Linux kernel for modern hardware support
- UEFI and Legacy BIOS boot support
- Passwordless sudo for convenience
- Docker ready with rootless configuration
- All filesystems supported (btrfs, ext4, xfs, f2fs, ntfs, vfat)

## Quick Start

### Download

Download the latest ISO from the [Releases](https://github.com/fransole/nixiso/releases) page.

### Write to USB

```bash
# Linux
sudo dd if=nixos-live-*.iso of=/dev/sdX bs=4M status=progress && sync

# macOS
sudo dd if=nixos-live-*.iso of=/dev/rdiskX bs=4m && sync

# Windows (use Rufus or Etcher)
# https://rufus.ie or https://etcher.io
```

Replace `/dev/sdX` with your USB device (check with `lsblk` or `fdisk -l`).

### Boot

1. Insert USB drive
2. Reboot and enter BIOS/UEFI (usually F2, F12, Del, or Esc)
3. Select USB drive from boot menu
4. Wait for GNOME to load (auto-login enabled)

### Default Credentials

- **Username**: `nixos`
- **Password**: (none - auto-login)
- **Sudo**: Passwordless

## Building Locally

### Prerequisites

- NixOS or any system with Nix installed
- Flakes enabled
- At least 8GB RAM and 50GB free disk space

### Build Command

```bash
# Clone the repository
git clone https://github.com/fransole/nixiso.git
cd nixiso

# Build the ISO
nix build .#nixosConfigurations.live-iso.config.system.build.isoImage

# Result will be in result/iso/
ls -lh result/iso/
```

### First build takes 60-90 minutes. Subsequent builds are faster with Nix cache.

### Test in QEMU

```bash
# After building
nix run nixpkgs#qemu -- \
  -cdrom result/iso/nixos-*.iso \
  -m 2048 \
  -enable-kvm
```

## Architecture

### File Structure

```
nixiso/
├── flake.nix                    # Main flake definition
├── iso-configuration.nix        # Core ISO settings
├── modules/
│   ├── gnome.nix               # GNOME desktop
│   ├── stylix.nix              # Dark mode theming
│   ├── dconf.nix               # GNOME settings
│   ├── packages.nix            # Package list
│   └── users.nix               # User configuration
├── assets/
│   └── p10k.zsh                # Powerlevel10k config
├── .github/workflows/
│   └── build-iso.yml           # CI/CD automation
└── instruction.md              # Runner setup guide
```

### Key Technologies

- **NixOS**: Reproducible system configuration
- **Stylix**: Unified theming system
- **Flakes**: Hermetic, reproducible builds
- **GitHub Actions**: Automated weekly builds
- **Self-hosted Runner**: Build on your own hardware

## Automated Builds

### Build Schedule

- **Weekly**: Every Monday at 00:00 UTC
- **On Push**: When configuration files change
- **Manual**: Via GitHub Actions interface

### Build Process

1. Runner checks out repository
2. Updates flake inputs to latest versions
3. Builds ISO with full tracing
4. Generates version tag (e.g., `v2026.01.13`)
5. Uploads ISO as artifact
6. Creates GitHub release with ISO attached
7. Cleans up build artifacts

### Build Time

- **First build**: 60-90 minutes
- **Incremental**: 20-40 minutes
- **Depends on**: CPU, RAM, cache availability

## Self-Hosted Runner Setup

See [instruction.md](instruction.md) for comprehensive setup guide.

### Quick Summary

**Option 1: github-nix-ci (Recommended)**

Add to your NixOS configuration:

```nix
{
  inputs.github-nix-ci.url = "github:juspay/github-nix-ci";

  services.github-nix-ci = {
    age.secretsDir = "/var/lib/secrets";
    runners.nixiso-builder = {
      owner = "fransole";
      repo = "nixiso";
      num = 1;
      tokenFile = "/var/lib/secrets/github-runner-token";
      labels = [ "self-hosted" "nixos" "x86_64-linux" ];
    };
  };
}
```

**Option 2: Manual Setup**

Follow instructions at: Settings → Actions → Runners → New self-hosted runner

**Option 3: Containerized Deployment (Homelab/Server)**

For Docker:
```bash
# See instruction.md for Dockerfile and docker-compose.yml
docker-compose up -d
```

For LXC/Proxmox:
- Download NixOS LXC template
- Create container with 4+ cores, 8-16GB RAM, 100GB storage
- Configure NixOS with flakes and binary caches
- Install GitHub runner as systemd service

See [instruction.md](instruction.md) for complete containerized setup guides.

## Customization

### Modify Packages

Edit `modules/packages.nix`:

```nix
environment.systemPackages = (with pkgs; [
  # Add your packages here
  vim
  htop
  # ...
]);
```

### Change Theme

Edit `modules/stylix.nix`:

```nix
base16Scheme = "${pkgs.base16-schemes}/share/themes/your-theme.yaml";
```

Available themes in: `/nix/store/*/share/themes/`

### Adjust GNOME Settings

Edit `modules/dconf.nix`:

```nix
"org/gnome/desktop/interface" = {
  # Your settings here
};
```

### Add Extensions

Edit `modules/gnome.nix`:

```nix
environment.systemPackages = with pkgs.gnomeExtensions; [
  your-extension
];
```

## Development

### Testing Changes

```bash
# Check flake validity
nix flake check

# Update dependencies
nix flake update

# Build and test
nix build .#nixosConfigurations.live-iso.config.system.build.isoImage
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build
5. Submit a pull request

## Troubleshooting

### Build Fails with "out of memory"

- Increase RAM or add swap
- Reduce compression level in `iso-configuration.nix`
- Close other applications during build

### ISO Won't Boot

- Verify ISO integrity: `sha256sum nixos-*.iso`
- Try different USB write tool (Rufus, Etcher, dd)
- Check BIOS settings (secure boot, UEFI vs Legacy)
- Verify USB device is bootable

### GNOME Doesn't Start

- Check system logs during boot
- Verify graphics drivers are loaded
- Try booting with `nomodeset` kernel parameter

### Runner Not Building

See [instruction.md](instruction.md) troubleshooting section.

## System Requirements

### For Running the ISO

- **CPU**: x86_64, 2+ cores recommended
- **RAM**: 2GB minimum, 4GB+ recommended
- **Storage**: USB drive 4GB+ or DVD
- **Boot**: UEFI or Legacy BIOS

### For Building the ISO

- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 50GB free space (100GB recommended)
- **OS**: NixOS or any Linux with Nix

## FAQ

**Q: Can I install NixOS from this ISO?**
A: No, this is a live-only environment. Use the official NixOS installer for installations.

**Q: Will my changes persist after reboot?**
A: No, this is a live environment. All changes are lost on reboot.

**Q: How do I save my work?**
A: Use external storage, network shares, or git repositories to save your work.

**Q: Can I add persistence?**
A: You could modify the configuration to add persistence, but it's not included by default.

**Q: Why is the ISO so large?**
A: It includes GNOME, development tools, and all dependencies (~2-3GB).

**Q: Can I use a different desktop environment?**
A: Yes, modify `modules/gnome.nix` to use KDE, XFCE, or others.

**Q: How do I update the ISO?**
A: Download the latest release or rebuild locally with `nix build`.

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Stylix Documentation](https://github.com/danth/stylix)
- [GitHub Actions Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Self-Hosted Runner Setup](instruction.md)

## License

MIT License - See LICENSE file for details

## Credits

- **NixOS**: The Nix community
- **Stylix**: Theme management
- **Kanagawa**: Color scheme by rebelot
- **Powerlevel10k**: ZSH theme by romkatv
- **Modern CLI tools**: bat, lsd, ripgrep, and others

## Support

- **Issues**: [GitHub Issues](https://github.com/fransole/nixiso/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fransole/nixiso/discussions)
- **NixOS**: [NixOS Discourse](https://discourse.nixos.org)
