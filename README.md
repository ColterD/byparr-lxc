# Byparr LXC Installation Script for Proxmox VE

A community fork providing Proxmox VE LXC installation scripts for **Byparr** - a self-hosted FlareSolverr alternative built with FastAPI and nodriver.

> **⚠️ Fork Notice**: This is a community fork by ColterD, following [Proxmox VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE) community standards.

## Quick Install

Run this command in your Proxmox VE Shell:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh)"
```

## About Byparr

Byparr is a drop-in replacement for FlareSolverr that provides reliable captcha solving and browser automation for your *arr applications. It's designed to work when FlareSolverr's captcha solver is broken.

### Features

- **FlareSolverr Compatible**: Works with existing *arr setups on port 8191
- **Browser Automation**: Uses Chrome with nodriver for reliability
- **FastAPI Based**: Modern, fast, and efficient
- **Auto Updates**: Built-in update functionality
- **Lightweight**: Runs in an unprivileged LXC container

## System Requirements

- Proxmox VE 8.1 or higher
- 2 CPU cores (minimum)
- 2GB RAM (minimum)
- 4GB disk space
- Internet connection

## Installation

### Method 1: Direct Install (Recommended)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh)"
```

### Method 2: Clone and Run

```bash
git clone https://github.com/ColterD/byparr-lxc.git
cd byparr-lxc
bash ct/byparr.sh
```

### Custom Configuration

You can customize the installation by setting environment variables before running the script:

```bash
# Example: Change the port from default 8191 to 9000
export BYPARR_PORT=9000

# Example: Increase RAM allocation to 4GB
export var_ram=4096

# Example: Use 4 CPU cores
export var_cpu=4

# Example: Allocate 8GB disk space
export var_disk=8

# Run the installer with custom settings
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh)"
```

## Post-Installation

### Accessing Byparr

After installation, Byparr will be available at:
```
http://[CONTAINER-IP]:8191
```

### Configuring *arr Applications

1. In your *arr application (Sonarr, Radarr, etc.):
2. Go to **Settings** → **Indexers**
3. Add or edit an indexer that requires FlareSolverr
4. Set **FlareSolverr URL** to: `http://[CONTAINER-IP]:8191`
5. Test and save

### Service Management

```bash
# Check status
systemctl status byparr

# View logs
journalctl -u byparr -f

# Restart service
systemctl restart byparr
```

### Updating Byparr

From within the container:
```bash
/opt/update-byparr.sh
```

Or from Proxmox host:
```bash
pct exec [CONTAINER-ID] /opt/update-byparr.sh
```

Or using the LXC update command:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh)" && update
```

## Troubleshooting

### Service Won't Start

1. Check logs: `journalctl -u byparr -n 50`
2. Verify Chrome: `google-chrome --version`
3. Test manually: `cd /opt/byparr && source "$HOME/.cargo/env" && uv run python -m byparr`

### Port Already in Use

Check what's using port 8191:
```bash
ss -tulpn | grep 8191
```

### Chrome/Display Issues

Verify Xvfb is running:
```bash
ps aux | grep Xvfb
```

### Dependency Issues

If you encounter UV package manager issues:
```bash
# Source the cargo environment
source "$HOME/.cargo/env"

# Check UV version
uv --version

# Reinstall UV if needed
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## File Locations

- **Application**: `/opt/byparr/`
- **Service**: `/etc/systemd/system/byparr.service`
- **Update Script**: `/opt/update-byparr.sh`
- **Wrapper Script**: `/opt/byparr/run_byparr_with_xvfb.sh`

## Credits

- **Byparr**: Created by [@ThePhaseless](https://github.com/ThePhaseless)
- **Original Script**: [@tanujdargan](https://github.com/tanujdargan)
- **Fork Maintainer**: [@ColterD](https://github.com/ColterD)
- **Framework**: [Proxmox VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE)

## Contributing

1. Fork the repository
2. Create your feature branch
3. Test thoroughly on Proxmox VE
4. Follow community standards from [Proxmox VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE)
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Links

- **This Fork**: [https://github.com/ColterD/byparr-lxc](https://github.com/ColterD/byparr-lxc)
- **Byparr**: [https://github.com/ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr)
- **Proxmox VE Helper Scripts**: [https://github.com/community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)
- **Original PR**: [#2959](https://github.com/community-scripts/ProxmoxVE/pull/2959)
