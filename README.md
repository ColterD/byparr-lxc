# Byparr Installation Scripts for Proxmox VE

## About

This repository contains installation scripts for **Byparr** - a self-hosted and open-source drop-in replacement for FlareSolverr. Byparr is built with FastAPI and nodriver, providing a reliable solution for solving captchas and browser challenges for your *arr applications when FlareSolverr's captcha solver is broken.

**⚠️ Notice: This is a ColterD community fork** - not yet officially part of the [community-scripts](https://github.com/community-scripts/ProxmoxVE) project. Once integrated, this fork will be deprecated.

## Quick Start

To create a Byparr LXC container, run this command in your Proxmox VE Shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh)"
```

> **Note**: Run this command **only** on the Proxmox VE host, not inside any container or VM.

## Prerequisites

- Proxmox VE 7.0 or higher
- Active internet connection
- At least 2GB free RAM
- At least 4GB free disk space

## Installation Methods

### Method 1: Quick Install (Recommended)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh)"
```

### Method 2: Download and Run

```bash
# Download the script
wget https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh

# Make it executable
chmod +x byparr.sh

# Run it
./byparr.sh
```

### Method 3: Clone Repository

```bash
# Clone the repository
git clone https://github.com/ColterD/byparr-lxc.git
cd byparr-lxc

# Run the container creation script
bash ct/byparr.sh
```

## Original Work Credit

This project builds upon work from multiple contributors:

### Byparr Application
Created by **[@ThePhaseless](https://github.com/ThePhaseless)**
- **Project**: [https://github.com/ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr)
- The core application providing FlareSolverr replacement functionality

### Proxmox Installation Script
Created by **[@tanujdargan](https://github.com/tanujdargan)**
- **Original Script**: [byparr-install.sh](https://github.com/tanujdargan/ProxmoxVE/blob/main/install/byparr-install.sh)
- **Original PR**: [community-scripts/ProxmoxVE #2959](https://github.com/community-scripts/ProxmoxVE/pull/2959)

Special thanks to both contributors for their excellent work!

## What This Fork Provides

### ✅ Fixed Issues
- Resolved "command not found" errors
- Fixed undefined variable issues
- Eliminated problematic `eval` usage
- Enhanced error handling throughout
- Improved output redirection

### 🚀 Enhanced Features
- **Community-Scripts Compliance**: Aligned with official standards
- **Professional Framework Integration**: Uses official `build.func`
- **Update Functionality**: Built-in update script with backup/rollback
- **Enhanced Security**: Unprivileged container with systemd hardening
- **Better Resource Management**: Optimized for browser automation
- **Comprehensive Logging**: Detailed installation and service logs

### 🛡️ Production Ready
- Robust service management
- UV package manager integration
- Automatic recovery mechanisms
- Clean installation process
- Backup support for updates

## Configuration

### Container Resources

| Setting | Default | Description |
|---------|---------|-------------|
| **CPU** | 2 cores | Required for browser operations |
| **RAM** | 2048 MB | Minimum for Chrome/Xvfb |
| **Disk** | 4 GB | OS + application + dependencies |
| **OS** | Debian 12 | Latest stable |
| **Privileged** | No | Security best practice |

### Network Settings

- **Port**: 8191 (FlareSolverr compatible)
- **Interface**: All interfaces (0.0.0.0)
- **Protocol**: HTTP

### Environment Variables

Customize Byparr by editing `/etc/systemd/system/byparr.service`:

```bash
Environment="LOG_LEVEL=info"        # Options: debug, info, warning, error
Environment="CAPTCHA_SOLVER=none"   # Captcha solving method
Environment="PORT=8191"             # Service port
```

## Usage

### Accessing Byparr

After installation, access Byparr at:
```
http://[CONTAINER-IP]:8191
```

To find your container IP:
```bash
pct exec [CTID] hostname -I
```

### Service Management

```bash
# Check service status
systemctl status byparr

# View logs
journalctl -u byparr -f

# Restart service
systemctl restart byparr

# Stop/Start service
systemctl stop byparr
systemctl start byparr
```

### Integration with *arr Apps

1. In your *arr application (Sonarr/Radarr/etc.):
   - Go to **Settings** → **Indexers**
   - Add or edit an indexer requiring FlareSolverr
   - Set **FlareSolverr URL** to: `http://[BYPARR-IP]:8191`
   - Test and save

### Updating Byparr

#### Method 1: Using Update Script
```bash
# Inside the container
/opt/byparr/update-byparr.sh
```

#### Method 2: From Proxmox Host
```bash
# Replace [CTID] with your container ID
pct exec [CTID] /opt/byparr/update-byparr.sh
```

## Troubleshooting

### Installation Issues

#### Script Not Found (404 Error)
```bash
# Verify GitHub is accessible
curl -I https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh

# Try wget instead
wget https://raw.githubusercontent.com/ColterD/byparr-lxc/main/ct/byparr.sh
bash byparr.sh
```

#### Framework Loading Issues
If you see framework warnings, the script will attempt to continue with limited functionality.

### Service Issues

#### Service Won't Start
```bash
# Check service status
systemctl status byparr -l

# Check for port conflicts
ss -tlnp | grep 8191

# Verify Xvfb is running
ps aux | grep Xvfb

# Test manual start
/opt/byparr/start-byparr.sh
```

#### Chrome/Browser Issues
```bash
# Verify Chrome installation
google-chrome --version

# Test Chrome with Xvfb
DISPLAY=:99 xvfb-run google-chrome --no-sandbox --headless --dump-dom https://example.com
```

#### Python/UV Issues
```bash
# Check UV installation
/root/.local/bin/uv --version

# Reinstall dependencies
cd /opt/byparr
/root/.local/bin/uv sync
```

### Common Error Messages

| Error | Solution |
|-------|----------|
| `CTID: unbound variable` | Run script on Proxmox host, not in container |
| `404` downloading script | Check internet connection and GitHub access |
| `Permission denied` | Run with appropriate privileges |
| `Port already in use` | Change port in systemd service file |

## File Structure

```
/opt/byparr/
├── start-byparr.sh         # Startup wrapper script
├── update-byparr.sh        # Update script
├── pyproject.toml          # Python project config
├── src/                    # Application source
└── .venv/                  # Python virtual environment

/etc/systemd/system/
└── byparr.service          # Systemd service

/root/.local/bin/
└── uv                      # UV package manager
```

## Development

### Building from Source

```bash
# Clone Byparr repository
git clone https://github.com/ThePhaseless/Byparr.git
cd Byparr

# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync

# Run development server
./cmd.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## Support

### Getting Help

1. **Check the logs**: `journalctl -u byparr -f`
2. **GitHub Issues**: [Create an issue](https://github.com/ColterD/byparr-lxc/issues)
3. **Community Scripts**: [Discord/Forum](https://community-scripts.github.io/ProxmoxVE/)

### Reporting Issues

When reporting issues, please include:
- Proxmox VE version
- Container configuration
- Error messages from logs
- Steps to reproduce

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **[@ThePhaseless](https://github.com/ThePhaseless)** - Byparr creator
- **[@tanujdargan](https://github.com/tanujdargan)** - Original Proxmox script
- **[community-scripts](https://github.com/community-scripts)** - Framework and standards
- **[tteck](https://github.com/tteck)** - Original Proxmox Helper Scripts

## Links

- **This Fork**: [GitHub](https://github.com/ColterD/byparr-lxc)
- **Byparr Project**: [GitHub](https://github.com/ThePhaseless/Byparr)
- **Community Scripts**: [GitHub](https://github.com/community-scripts/ProxmoxVE)
- **Original PR**: [#2959](https://github.com/community-scripts/ProxmoxVE/pull/2959)

---

**Note**: This is a community-maintained fork. Always review scripts before running them in production environments. This project is not officially affiliated with or endorsed by the community-scripts project (yet).
