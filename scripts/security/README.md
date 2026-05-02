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

You can generate an SSH key pair in a password manager vault and use the **same public key** on the server and the private key on every device that vault supports.

### Rules of thumb

- Install only the **public** key (one line: `ssh-ed25519 AAAA… comment`) into each Unix account’s `~/.ssh/authorized_keys` you need to use (`chmod 700` `~/.ssh`, `chmod 600` `authorized_keys`).
- Never commit or paste the **private** key into the repo or chat.
- On many clouds, **`root`**’s `authorized_keys` uses **`command=`** (forced message / break-glass). Put your day-to-day **public** key on the **created user** via **`new-sudo-user.sh`**’s paste step; the script **never** reads or writes **`/root/.ssh`**, so break-glass keys stay as the provider left them.
- If the script prints **could not parse** / **WARNING** after a paste, the **public** line may be **truncated**—re-copy the full single line from the vault.

### Root cause: rich-text editors break private keys

Saving a **private key** with **TextEdit** (default RTF/plain quirks), **Word**, or mail clients often introduces **curly quotes**, wrong **line endings**, **BOM**, or truncated lines. OpenSSH then reports **`is not a key file`** or **`invalid format`** even when Bitwarden generated a valid pair.

**Fix:** copy the **private key** from Bitwarden to the **system clipboard**, then write it with a **shell** (or another tool below) so bytes stay exact. Always verify:

```bash
ssh-keygen -lf ~/.ssh/your_chosen_filename
```

…must succeed and show the expected type (e.g. **ED25519**) and fingerprint matching your **public** line.

### Clipboard to file (fastest; use real paths)

**macOS** (Terminal; avoid TextEdit for the key body):

```bash
pbpaste > ~/.ssh/oracle_btm_ed25519
chmod 600 ~/.ssh/oracle_btm_ed25519
ssh-keygen -lf ~/.ssh/oracle_btm_ed25519
```

**Linux** (X11, if `xclip` is installed):

```bash
xclip -selection clipboard -o > ~/.ssh/oracle_btm_ed25519
chmod 600 ~/.ssh/oracle_btm_ed25519
ssh-keygen -lf ~/.ssh/oracle_btm_ed25519
```

**Linux** (Wayland, if `wl-clipboard` is installed): `wl-paste > ~/.ssh/oracle_btm_ed25519` then `chmod 600` and `ssh-keygen -lf` as above.

**Linux** (no clipboard tool): `nano ~/.ssh/oracle_btm_ed25519`, paste once, save; or `cat > ~/.ssh/oracle_btm_ed25519`, paste, then **Ctrl-D**; then `chmod 600`.

**Windows** (PowerShell; multiline clipboard):

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh" | Out-Null
Get-Clipboard -Raw | Set-Content -Path "$env:USERPROFILE\.ssh\oracle_btm_ed25519" -Encoding utf8NoBOM
```

For **OpenSSH for Windows**, remove inherited ACLs and grant **only** your user access (adjust the path if needed):

```powershell
$key = "$env:USERPROFILE\.ssh\oracle_btm_ed25519"
icacls $key /inheritance:r
icacls $key /grant:r "$($env:USERNAME):F"
```

Then test: `ssh-keygen -lf "$env:USERPROFILE\.ssh\oracle_btm_ed25519"`.

Prefer **VS Code** or **Notepad** saving **UTF-8** (no BOM) if you edit by hand; avoid smart quotes.

### Optional GUI / clients (macOS)

If you do not want to rely on Terminal for daily SSH:

| Client | Best for | Notes |
|--------|----------|-------|
| **Termius** | PuTTY-like workflow | Integrated host list and key manager; paste private keys from Bitwarden; sync across devices; replaces PuTTY / PuTTYgen-style flow for many users. |
| **iTerm2** | Terminal-first | Replacement for Terminal.app; works with native `ssh` and `~/.ssh/config`; fewer paste and scroll annoyances than default terminal. |
| **VS Code + Remote SSH** | Development | Remote explorer and integrated terminal; uses your existing SSH config and `IdentityFile` paths under the hood. |

### Optional tooling (Windows and Linux)

| Platform | Option | Notes |
|----------|--------|-------|
| **Windows** | **Windows Terminal** + OpenSSH | Built-in `ssh`; use PowerShell clipboard-to-file above; fix **icacls** on private keys for OpenSSH for Windows. |
| **Windows** | **PuTTY** | Common legacy stack; uses `.ppk` keys unless you convert with PuTTYgen or point PuTTY at OpenSSH-format keys where supported. |
| **Windows** | **VS Code + Remote SSH** | Same remote workflow as on macOS; keep keys in `~/.ssh` with correct permissions. |
| **Linux** | **Native `ssh` in any terminal** | Prefer clipboard tools or `nano`/`vim` / here-doc for keys; avoid word processors. |
| **Linux** | **Terminator, Tilix, Konsole, etc.** | Terminal multiplexers / better tabs; still use system `ssh` and plain-text key files. |
| **Linux** | **VS Code + Remote SSH** | Same as other platforms if you develop on the box you SSH from. |

### SSH client config (`~/.ssh/config`)

Use one entry per server so you can run **`ssh my-alias`** instead of long commands. Paths below use **`~/.ssh/`** (on **Windows** with OpenSSH this maps under **`%USERPROFILE%\.ssh`**).

**Create or edit the file**

**macOS / Linux** (Terminal):

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/config
chmod 600 ~/.ssh/config
```

**Windows** (PowerShell; create file if missing):

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh" | Out-Null
notepad "$env:USERPROFILE\.ssh\config"
# After save, restrict config file (recommended):
icacls "$env:USERPROFILE\.ssh\config" /inheritance:r
icacls "$env:USERPROFILE\.ssh\config" /grant:r "$($env:USERNAME):F"
```

Paste a template below, then **replace every `CHANGE_ME`** and the example **`Host my-alias`** name if you like. Duplicate the **`Host`** block (or uncomment the second block) for more servers. Test with **`ssh -G my-alias`** (substitute your **`Host`** keyword; prints resolved config) then **`ssh my-alias`**.

**macOS** (includes Keychain integration supported by Apple’s OpenSSH build):

```text
# First host — rename Host alias and set HostName / User / IdentityFile
Host my-alias                          # CHANGE: short label; connect with: ssh my-alias
    HostName CHANGE_ME                 # CHANGE: server DNS or IP from your provider
    User CHANGE_ME                     # CHANGE: Unix account on that server
    IdentityFile ~/.ssh/CHANGE_ME      # CHANGE: private key file for this host (chmod 600)

    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes

    StrictHostKeyChecking ask
    PreferredAuthentications publickey

    AddKeysToAgent yes
    UseKeychain yes

    Compression yes
    LogLevel INFO

# --- Add more servers: copy the whole Host block above, or uncomment and edit below ---
# Host another-alias
#     HostName CHANGE_ME
#     User CHANGE_ME
#     IdentityFile ~/.ssh/CHANGE_ME
#     IdentitiesOnly yes
#     ServerAliveInterval 60
#     ServerAliveCountMax 3
#     TCPKeepAlive yes
#     StrictHostKeyChecking ask
#     PreferredAuthentications publickey
#     AddKeysToAgent yes
#     UseKeychain yes
#     Compression yes
#     LogLevel INFO
```

**Linux** (same behaviour except **no** `UseKeychain`; `AddKeysToAgent` is optional—remove both agent lines if your distro’s `ssh` warns about unknown options):

```text
Host my-alias                          # CHANGE
    HostName CHANGE_ME                 # CHANGE
    User CHANGE_ME                     # CHANGE
    IdentityFile ~/.ssh/CHANGE_ME      # CHANGE

    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes

    StrictHostKeyChecking ask
    PreferredAuthentications publickey

    AddKeysToAgent yes

    Compression yes
    LogLevel INFO

# Host another-alias
#     HostName CHANGE_ME
#     User CHANGE_ME
#     IdentityFile ~/.ssh/CHANGE_ME
#     IdentitiesOnly yes
#     ServerAliveInterval 60
#     ServerAliveCountMax 3
#     TCPKeepAlive yes
#     StrictHostKeyChecking ask
#     PreferredAuthentications publickey
#     AddKeysToAgent yes
#     Compression yes
#     LogLevel INFO
```

**Windows** (OpenSSH; **no** `UseKeychain`). You may use forward slashes in **`IdentityFile`**, e.g. **`~/.ssh/CHANGE_ME`**:

```text
Host my-alias                          # CHANGE
    HostName CHANGE_ME                 # CHANGE
    User CHANGE_ME                     # CHANGE
    IdentityFile ~/.ssh/CHANGE_ME      # CHANGE

    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes

    StrictHostKeyChecking ask
    PreferredAuthentications publickey

    AddKeysToAgent yes

    Compression yes
    LogLevel INFO

# Host another-alias
#     HostName CHANGE_ME
#     User CHANGE_ME
#     IdentityFile ~/.ssh/CHANGE_ME
#     IdentitiesOnly yes
#     ServerAliveInterval 60
#     ServerAliveCountMax 3
#     TCPKeepAlive yes
#     StrictHostKeyChecking ask
#     PreferredAuthentications publickey
#     AddKeysToAgent yes
#     Compression yes
#     LogLevel INFO
```

If **`ssh`** reports an unknown option, remove the line or check **`man ssh_config`** for your OpenSSH version.

### Auth still failing?

**“Permission denied (publickey)”** is usually on the **client**: **`IdentityFile`** must reference a **valid OpenSSH private key** for the same pair as a line in **`authorized_keys`**. OpenSSH format starts with **`-----BEGIN OPENSSH PRIVATE KEY-----`** for many modern keys. Filename **labels** (e.g. `rsa-key-…`) do not change the algorithm inside the file. **`ssh -vvv`** shows which keys the client offers. Server-side **`new-sudo-user.sh`** prints **`ssh-keygen -lf`** on **`authorized_keys`** for comparison.

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
