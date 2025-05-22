{
  "name": "Byparr",
  "slug": "byparr",
  "categories": ["Media"],
  "date_created": "2025-05-21",
  "type": "ct",
  "updateable": true,
  "privileged": false,
  "interface_port": 8191,
  "documentation": "https://github.com/ThePhaseless/Byparr",
  "website": "https://github.com/ThePhaseless/Byparr",
  "logo": "https://raw.githubusercontent.com/ThePhaseless/Byparr/main/logo.png",
  "description": "Byparr is a self-hosted and open-source drop-in replacement for FlareSolverr. Built with FastAPI and nodriver, it provides a reliable solution for solving captchas and browser challenges for your *arr applications when FlareSolverr's captcha solver is broken.",
  "install_methods": [
    {
      "type": "default",
      "script": "ct/byparr.sh"
    }
  ],
  "default_credentials": {
    "username": "",
    "password": ""
  },
  "notes": {
    "version": "This script installs the latest version of Byparr from the official GitHub repository.",
    "compose": "Byparr runs as a native Python application using UV package manager for dependency management.",
    "resources": "Recommended minimum resources: 2 CPU cores, 2GB RAM, 4GB storage.",
    "network": "Byparr listens on port 8191 by default and can be configured through environment variables.",
    "updates": "The container can be updated using the built-in update function that pulls the latest code and dependencies.",
    "migration": "To migrate from FlareSolverr, simply change your *arr application's proxy settings to point to this Byparr instance.",
    "troubleshooting": "Check service status with 'systemctl status byparr' and view logs with 'journalctl -u byparr -f'."
  },
  "tags": [
    "captcha",
    "solver", 
    "arr",
    "proxy",
    "flaresolverr",
    "alternative",
    "browser",
    "automation"
  ],
  "repository": {
    "url": "https://github.com/ThePhaseless/Byparr",
    "branch": "main"
  },
  "requirements": {
    "proxmox_version": "8.0+",
    "minimum_resources": {
      "cpu_cores": 2,
      "ram_mb": 2048,
      "disk_gb": 4
    }
  },
  "environment_variables": {
    "LOG_LEVEL": {
      "description": "Set logging level (debug, info, warning, error)",
      "default": "info",
      "required": false
    },
    "CAPTCHA_SOLVER": {
      "description": "Captcha solving method",
      "default": "none",
      "required": false
    },
    "PORT": {
      "description": "Port for Byparr to listen on",
      "default": "8191",
      "required": false
    }
  },
  "ports": [
    {
      "container_port": 8191,
      "protocol": "tcp",
      "description": "Byparr web interface and API"
    }
  ],
  "volumes": [
    {
      "container_path": "/opt/byparr",
      "description": "Application directory containing Byparr installation"
    }
  ],
  "health_check": {
    "endpoint": "http://localhost:8191/health",
    "timeout": 30
  }
}
