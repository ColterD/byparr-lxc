# Byparr Installation Scripts for Proxmox VE

## About

This repository contains refactored installation scripts for **Byparr** - a self-hosted and open-source drop-in replacement for FlareSolverr. Byparr is built with FastAPI and nodriver, providing a reliable solution for solving captchas and browser challenges for your *arr applications when FlareSolverr's captcha solver is broken.

Once the [ProxmoxVE Community Scripts](https://github.com/community-scripts/ProxmoxVE) project builds their own version of the Byparr LXC script, this repository will be deprecated.

### Original Work Credit

This project builds upon work from multiple contributors:

**Byparr Application**: Created by **[@ThePhaseless](https://github.com/ThePhaseless)**
- **Byparr Project**: [https://github.com/ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr)
- The core application that provides FlareSolverr replacement functionality

**Proxmox Installation Script**: Created by **[@tanujdargan](https://github.com/tanujdargan)**
- **Original Script**: [byparr-install.sh](https://github.com/tanujdargan/ProxmoxVE/blob/main/install/byparr-install.sh)
- **Original Pull Request**: [community-scripts/ProxmoxVE #2959](https://github.com/community-scripts/ProxmoxVE/pull/2959)

Special thanks to **ThePhaseless** for creating the excellent Byparr application and to **tanujdargan** for the initial Proxmox installation script implementation and contribution to the community!

## What This Refactored Version Provides

### ✅ **Fixed Issues from Original**
- **Resolved "command not found" errors** by implementing proper function definitions
- **Fixed undefined variable issues** (RANDOM_UUID, FUNCTIONS_FILE_PATH, etc.)
- **Eliminated problematic `eval` usage** with proper command execution
- **Enhanced error handling** with robust error checking and logging
- **Improved output redirection** with clean verbose/quiet modes

### 🚀 **Enhanced Features**
- **Community-Scripts Compliance**: Fully aligned with [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) standards
- **Professional Framework Integration**: Uses official `build.func` and follows established patterns
- **Proper Update Functionality**: Built-in update script that can upgrade Byparr installations
- **Enhanced Security**: Runs unprivileged by default with proper systemd security settings
- **Better Resource Management**: Proper container resource allocation and checking
- **Comprehensive Logging**: Detailed installation and operation logs
- **Standard UX**: Consistent with other community-scripts installations

### 🛡️ **Production Ready**
- **Robust Service Management**: Enhanced systemd service configuration
- **Dependency Isolation**: Proper UV package manager integration
- **Auto-recovery**: Service restart policies and health checking
- **Clean Installation**: Proper cleanup and optimization
- **Backup Support**: Update process includes automatic backups

## Installation

### Quick Install (Recommended)

Run this command in your Proxmox VE shell:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/byparr.sh)"
```

### Manual Installation

1. **Download the scripts:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/byparr-scripts/main/ct/byparr.sh
   wget https://raw.githubusercontent.com/your-repo/byparr-scripts/main/install/byparr-install.sh
   ```

2. **Make executable:**
   ```bash
   chmod +x byparr.sh byparr-install.sh
   ```

3. **Run the container creation script:**
   ```bash
   ./byparr.sh
   ```

## Configuration

### Default Container Settings

| Setting | Value | Description |
|---------|-------|-------------|
| **CPU Cores** | 2 | Recommended minimum for Chrome operations |
| **RAM** | 2048 MB | Sufficient for browser automation |
| **Disk** | 4 GB | Application and dependencies storage |
| **OS** | Debian 12 | Latest stable Debian |
| **Privileged** | No | Runs unprivileged for security |

### Network Configuration

- **Default Port**: 8191 (FlareSolverr compatible)
- **Protocol**: HTTP
- **Interface**: All interfaces (0.0.0.0)

### Environment Variables

You can customize Byparr behavior by modifying `/etc/systemd/system/byparr.service`:

```bash
Environment="LOG_LEVEL=info"           # debug, info, warning, error
Environment="CAPTCHA_SOLVER=none"      # Captcha solving method
Environment="PORT=8191"                # Service port (optional)
```

## Usage

### Accessing Byparr

After installation, access Byparr at:
```
http://[CONTAINER-IP]:8191
```

### Service Management

```bash
# Check service status
systemctl status byparr

# Start/Stop/Restart service
systemctl start byparr
systemctl stop byparr
systemctl restart byparr

# View logs
journalctl -u byparr -f

# Enable/Disable auto-start
systemctl enable byparr
systemctl disable byparr
```

### Integration with *arr Applications

Configure your *arr applications (Sonarr, Radarr, etc.) to use Byparr as a proxy:

1. Go to Settings → Indexers → Add Indexer
2. Select an indexer that requires FlareSolverr
3. Set **FlareSolverr URL** to: `http://[BYPARR-IP]:8191`
4. Test and save the configuration

### Updating Byparr

The installation includes an automatic update function:

```bash
# Run the update script
/opt/byparr/update-byparr.sh

# Or use the built-in function
bash -c "$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/byparr.sh)" update
```

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check detailed service status
systemctl status byparr -l

# Check if UV is properly installed
/root/.local/bin/uv --version

# Manually test the application
cd /opt/byparr
/opt/byparr/start-byparr.sh
```

#### Chrome/Browser Issues
```bash
# Verify Chrome installation
google-chrome --version

# Check display server
echo $DISPLAY

# Test X virtual framebuffer
ps aux | grep Xvfb
```

#### Dependency Issues
```bash
# Reinstall UV package manager
curl -LsSf https://astral.sh/uv/install.sh | sh
source /root/.local/bin/env

# Reinstall Byparr dependencies
cd /opt/byparr
uv sync --group test
```

### Log Files

- **Installation Log**: `/var/log/byparr-install.log`
- **Service Logs**: `journalctl -u byparr`
- **Application Logs**: Check service environment for log file locations

### Getting Help

1. **Check Service Status**: `systemctl status byparr -l`
2. **View Recent Logs**: `journalctl -u byparr -n 50`
3. **Test Manual Start**: `/opt/byparr/start-byparr.sh`
4. **Verify Network**: `netstat -tlnp | grep 8191`

## File Structure

```
/opt/byparr/                    # Main application directory
├── start-byparr.sh            # Service startup script
├── cmd.sh                     # Application entry point
├── pyproject.toml             # Python project configuration
└── src/                       # Source code

/etc/systemd/system/
└── byparr.service             # Systemd service definition

/var/log/
└── byparr-install.log         # Installation log
```

## Development

### Local Development

```bash
# Clone the repository
git clone https://github.com/ThePhaseless/Byparr.git
cd Byparr

# Install dependencies
uv sync --group test

# Run development server
./cmd.sh
```

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **[@tanujdargan](https://github.com/tanujdargan)** - Original script author and initial implementation
- **[@ThePhaseless](https://github.com/ThePhaseless)** - Byparr application developer
- **[community-scripts](https://github.com/community-scripts)** - Framework and standards
- **[tteck](https://github.com/tteck)** - Original Proxmox Helper Scripts inspiration

## Links

- **Byparr Project**: [GitHub](https://github.com/ThePhaseless/Byparr)
- **Community Scripts**: [GitHub](https://github.com/community-scripts/ProxmoxVE)
- **Original PR**: [#2959](https://github.com/community-scripts/ProxmoxVE/pull/2959)
- **Documentation**: [Helper Scripts Website](https://community-scripts.github.io/ProxmoxVE/)

---

**Note**: This is a community-maintained script. Always review scripts before running them in production environments.
