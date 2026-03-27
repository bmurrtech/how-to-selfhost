# Security scripts

Scripts for user management, SSH hardening, and Fail2ban. Intended for **home LAN** or **VPS** use; read each script’s notes for lockout risk (e.g. SSH/AllowUsers, Fail2ban whitelist).

## Why use these

- **Automate safe baselines**: Create sudo users with SSH keys, harden SSH, and install Fail2ban with sensible whitelists so you don’t lock yourself out.
- **Repeatable**: Same steps every time; all scripts in this folder are written to be **safe to re-run** (see **Idempotency** below).
- **Documented**: Each script’s behavior is summarized below so you can decide whether to run it.

## Idempotency

- **`f2b-install.sh`**: Rewrites the same Fail2ban config files each run and **`systemctl restart fail2ban`** so changes (e.g. new `--whitelist`) apply; `apt install` is a no-op when already installed.
- **`vps-sec-harden.sh`**: Skips duplicate sysctl/fstab/sshd template lines; **UFW** skips `allow` rules that already match **Anywhere** for 22/80/443 (and the chosen SSH source IP when applicable); skips `dpkg-reconfigure unattended-upgrades` if `20auto-upgrades` already exists. Package upgrades still run unless you skip them manually.
- **`new-sudo-user.sh`**: If the account exists **and** passwd’s home is **`/home/<username>`** (canonical match), a menu offers **[1]** backup+**`userdel`**+recreate+restore, **[2]** destructive fresh overwrite (no backup), or **[3]** default idempotent steps only. If the account exists but home is non-standard or missing, **no** menu—only idempotent steps. Keys from **pasted** public lines only; **never** touches `/root/.ssh`.

## High-level overview (what each script does)

| Script | Main actions (no secrets logged) |
|--------|----------------------------------|
| **f2b-install.sh** | Installs Fail2ban; builds `ignoreip` from RFC1918 + your whitelist; writes `/etc/fail2ban/jail.local` and `jail.d/*`; enables jails for sshd, postfix, dovecot, sieve, coturn (nginx optional). |
| **new-sudo-user.sh** | Run as **root**: creates user, or if user exists **and** home is **`/home/name`**, menu **[1/2/3]** for backup+restore, destructive new home, or keep; non-standard home → no recreate menu; **`authorized_keys`** from paste only; optional `AllowUsers`; restarts SSH; moves to `/root/scripts`. |
| **vps-sec-harden.sh** | Runs as your user (sudo): apt update/upgrade; disables IPv6 in sysctl; hardens sshd (PermitRootLogin no, password auth off, PAM unchanged); appends optional commented `AllowUsers` example only; installs UFW (22 / 80 / 443, optional SSH limited by source IP); disables `rpcbind` when present; secures `/run/shm` in fstab; unattended-upgrades; restarts sshd. |

## Recommended order (fresh VPS)

1. Log in as the provider’s default user (or serial/console) and install your **public** key in that user’s `~/.ssh/authorized_keys` (see **Vault-managed SSH keys** below).
2. **Optional:** Run **`new-sudo-user.sh`** as root if you need an extra sudo account **before** full hardening. Prefer **AllowUsers? (y/N)** → **N** so behavior stays aligned with **`vps-sec-harden.sh`** (no enforced user list). Use **y** only when you intentionally want `AllowUsers admin newuser` and you name the real admin (e.g. `ubuntu`), not `root`, if root login is disabled later.
3. Run **`vps-sec-harden.sh`** as the sudo user you will actually use day to day, after key login works from a **second** SSH session.

## Vault-managed SSH keys (e.g. Bitwarden)

You can generate an SSH key pair in a password manager vault and use the **same public key** on the server and the private key on every device that vault supports. Rules of thumb:

- Install only the **public** key (one line: `ssh-ed25519 AAAA… comment`) into each Unix account’s `~/.ssh/authorized_keys` you need to use (`chmod 700` `~/.ssh`, `chmod 600` `authorized_keys`).
- Never commit or paste the **private** key into the repo or chat.
- On many clouds, **`root`**’s `authorized_keys` uses **`command=`** (forced message / break-glass). Put your day-to-day **public** key on the **created user** via **`new-sudo-user.sh`**’s paste step; the script **never** reads or writes **`/root/.ssh`**, so break-glass keys stay as the provider left them.

## Intended environment

- **Home / on-prem**: RFC1918 is typically whitelisted so you don’t lock yourself out from inside your network.
- **VPS / cloud**: Use `--whitelist` (or whitelist-file) for your admin IP(s). Consider `vps-sec-harden.sh` only after you have console access (e.g. provider serial/console) in case SSH is restarted.

## Safety notes

- **SSH hardening (`vps-sec-harden.sh`)**: Disables root login and password auth; does not enforce `AllowUsers` (see commented template in `sshd_config`). Ensure key-based login works and **test from a second SSH session** before closing your first. If you choose **static IP** for SSH in the UFW prompt, a wrong address can block new SSH sessions from other IPs; use your provider’s **console** to recover. PAM remains enabled (cloud-friendly).
- **Fail2ban (`f2b-install.sh`)**: By default whitelists loopback and RFC1918. On a cloud VM, add your public IP with `--whitelist` so you don’t ban yourself.
- **New sudo user (`new-sudo-user.sh`)**: **AllowUsers** optional (default **N** for that prompt). Run via **`sudo`** when using restricted `AllowUsers`. Public keys via paste only. **Recreate** options **[1]/[2]** appear only when passwd home is **`/home/<username>`**; **[2]** is destructive (no backup). Uses console if **`userdel`** could fail. Failed restore from **[1]** leaves backup paths in the log.

## How to download (wget)

From a Linux host (e.g. SSH or Proxmox console), use the raw URL for this repo (replace `main` with your branch if different):

```bash
# Fail2ban installer
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/f2b-install.sh -O f2b-install.sh
chmod +x f2b-install.sh

# New sudo user
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/new-sudo-user.sh -O new-sudo-user.sh
chmod +x new-sudo-user.sh

# VPS SSH/system hardening (unattended-upgrades, UFW, etc.)
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/vps-sec-harden.sh -O vps-sec-harden.sh
chmod +x vps-sec-harden.sh
```

Run with appropriate privileges (e.g. `sudo ./f2b-install.sh`, `sudo ./new-sudo-user.sh`, or run `vps-sec-harden.sh` as a sudo user).

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

Creates a sudo user with password (not logged). If the account **already exists** and **`getent passwd`** home matches **`/home/<username>`**, you get **[1]** backup home then recreate+restore, **[2]** **`userdel`** + remove home with **no** backup, or **[3]** default: keep the account (idempotent sudo/SSH/`AllowUsers` only). Otherwise (non-standard home) there is **no** recreate prompt. **`authorized_keys`** only from **pasted** lines. Relocates to `/root/scripts` after first run.

---

## vps-sec-harden.sh

Updates packages, disables IPv6, hardens SSH (PermitRootLogin no, password auth off; leaves **UsePAM** at the distro default), prints a short **authorized_keys** checklist, adds UFW (incoming default deny; **22** either worldwide or from one IP you enter; **80** and **443**), stops **rpcbind** if installed, secures shared memory, and installs unattended-upgrades. **Use console access** if you might lock yourself out (bad `sshd_config` or wrong UFW SSH IP). Ensure the username you use is in the `sudo` group before running.
