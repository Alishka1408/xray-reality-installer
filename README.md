# xray-reality-installer

One-command installer for **Xray (VLESS + Reality)** with secure defaults, automatic key generation, systemd & UFW setup, and simple CLI tools for user management and link sharing.

This project is designed to provide a **minimal, production-ready VPN server setup** with a focus on simplicity, stealth, and reproducibility.

---

## Features

-  One-command installation (`curl | bash`)
-  Automatic Reality (X25519) key generation
-  Secure, minimal Xray configuration (VLESS + Reality)
-  systemd integration (auto-start on boot)
-  UFW firewall configuration (SSH + 443)
-  Built-in CLI tools for user management
-  QR-code and share link generation
-  No hardcoded secrets — everything is generated on the server

---

## Requirements

- Ubuntu / Debian-based Linux
- Root access (`sudo -i`)
- Public IPv4 address
- Open port **443/TCP**

---

## Quick Start

#### Run the installer as **root**:

```bash
sudo -i
bash <(curl -fsSL https://raw.githubusercontent.com/Alishka1408/xray-reality-installer/main/install.sh)
```

#### After installation, the script will output:
- Server IP
- Main user connection link
- QR code for quick import

---

## What Gets Installed
	•	Xray Core
	•	Configuration files:
	•	/usr/local/etc/xray/config.json
	•	/usr/local/etc/xray/.keys
	•	Helper commands:
	•	mainuser
	•	newuser
	•	rmuser
	•	sharelink
	•	Firewall rules via UFW
	•	systemd service (xray.service)

---

## User Management Commands

#### Show main user link
```bash
mainuser
```

#### Add a new user
```bash
newuser
```

#### Remove an existing user
```bash
rmuser
```

#### Share a link for an existing user
```bash
sharelink
```

#### Each command outputs:
- VLESS + Reality connection link
- QR code (ANSI, terminal-friendly)

---

#### Configuration Notes
- The server uses VLESS over TCP with Reality
- No TLS certificates are required
- No domain name is required
- Default camouflage destination: www.github.com
- Logging is enabled at info level (can be changed to warning for production)

---

#### Security Notes
- All keys are generated locally on the server
- Never reuse .keys between servers
- Do not commit /usr/local/etc/xray/.keys anywhere
- For best security, review the generated config.json before production use

---

#### Customization

You may want to:
- Change serverNames and dest in Reality settings
- Switch loglevel to warning
- Add additional inbounds or outbounds
- Use IPv6 if required
- Add Fail2Ban or other hardening tools

---

## Disclaimer

This project is provided as-is, for educational and personal use.
You are responsible for complying with local laws and regulations.