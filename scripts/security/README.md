# Security scripts

Scripts for user management, SSH hardening, and Fail2ban. Intended for **home LAN** or **VPS** use; read each script’s notes for lockout risk (e.g. SSH/AllowUsers, Fail2ban whitelist).

## Why use these

- **Automate safe baselines**: Create sudo users with SSH keys, harden SSH, and install Fail2ban with sensible whitelists so you don’t lock yourself out.
- **Repeatable**: Same steps every time; idempotent where possible (e.g. f2b-install.sh).
- **Documented**: Each script’s behavior is summarized below so you can decide whether to run it.

## High-level overview (what each script does)

| Script | Main actions (no secrets logged) |
|--------|----------------------------------|
| **f2b-install.sh** | Installs Fail2ban; builds `ignoreip` from RFC1918 + your whitelist; writes `/etc/fail2ban/jail.local` and `jail.d/*`; enables jails for sshd, postfix, dovecot, sieve, coturn (nginx optional). |
| **new-sudo-user.sh** | Prompts for username and password; creates user, sets password, adds to sudo; copies `~/.ssh/authorized_keys` to new user; appends `AllowUsers` in `sshd_config`; restarts sshd; moves itself to `/root/scripts`. |
| **secops.sh** | Runs as your user (sudo): apt update/upgrade; disables IPv6 in sysctl; sets PermitRootLogin no, PasswordAuthentication no, AllowUsers in sshd_config; secures `/run/shm` in fstab; installs unattended-upgrades; restarts sshd. |

## Intended environment

- **Home / on-prem**: RFC1918 is typically whitelisted so you don’t lock yourself out from inside your network.
- **VPS / cloud**: Use `--whitelist` (or whitelist-file) for your admin IP(s). Consider `secops.sh` only after you have console access (e.g. provider serial/console) in case SSH is restarted.

## Safety notes

- **SSH hardening (`secops.sh`)**: Disables root login and password auth, restricts `AllowUsers`. Run only when you have **console access** (e.g. Proxmox VM console) so you can fix SSH if needed.
- **Fail2ban (`f2b-install.sh`)**: By default whitelists loopback and RFC1918. On a cloud VM, add your public IP with `--whitelist` so you don’t ban yourself.
- **New sudo user (`new-sudo-user.sh`)**: Copies SSH keys and updates `AllowUsers`. Ensure the user running the script (or root) has a valid `~/.ssh/authorized_keys` if you rely on key-based login.

## How to download (wget)

From a Linux host (e.g. SSH or Proxmox console), use the raw URL for this repo (replace `main` with your branch if different):

```bash
# Fail2ban installer
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/f2b-install.sh -O f2b-install.sh
chmod +x f2b-install.sh

# New sudo user
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/new-sudo-user.sh -O new-sudo-user.sh
chmod +x new-sudo-user.sh

# Secops (SSH hardening, unattended-upgrades, etc.)
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/secops.sh -O secops.sh
chmod +x secops.sh
```

Run with appropriate privileges (e.g. `sudo ./f2b-install.sh`, `sudo ./new-sudo-user.sh`, or run `secops.sh` as a sudo user).

---

## f2b-install.sh — Fail2ban installer

Lightweight Fail2ban setup with CLI whitelist flags. By default:

- Whitelists loopback and **RFC1918** (10/8, 172.16/12, 192.168/16).
- Auto-picks `nftables-multiport` or `iptables-multiport`.
- Enables jails only for services present: **sshd**, **postfix**, **dovecot**, **sieve**, **coturn**. **nginx** jails are **disabled** unless `--enable-nginx`.

### Quickstart

```bash
# Default (home / on-prem)
sudo ./f2b-install.sh

# Cloud VM — whitelist your public IP for SSH
sudo ./f2b-install.sh --whitelist "203.0.113.7"

# Multiple IPs or from file
sudo ./f2b-install.sh --whitelist-file /root/allow.txt
sudo ./f2b-install.sh --enable-nginx   # only if nginx logs show real client IPs
```

### Verify / operate

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
# Emergency unban (from console):
sudo fail2ban-client unban --all
```

---

## new-sudo-user.sh

Creates a new user with sudo, sets password (not logged), copies SSH keys from the current user, and updates `AllowUsers` in `sshd_config`. Run as root. The script relocates itself to `/root/scripts` after first run.

---

## secops.sh

Updates packages, disables IPv6, hardens SSH (PermitRootLogin no, password auth no, AllowUsers), secures shared memory, and installs unattended-upgrades. **Run only with console access** in case SSH restarts; ensure the username you enter is in the sudo group before running.
