#!/usr/bin/env bash
# f2b-install.sh — lightweight Fail2ban with CLI whitelist flags
# Usage examples:
#   sudo ./f2b-install.sh --whitelist "203.0.113.7,198.51.100.10/32"
#   sudo ./f2b-install.sh --whitelist 203.0.113.7 --whitelist 198.51.100.10/32
#   sudo ./f2b-install.sh --whitelist-file /root/my-ips.txt --enable-nginx
#   sudo ./f2b-install.sh --no-rfc1918

set -euo pipefail

# ------------ arg parsing ------------
WHITELIST=()          # additional IPs/CIDRs to ignore
WHITELIST_FILE=""
ENABLE_NGINX="false"
INCLUDE_RFC1918="true"

print_help() {
  cat <<USAGE
f2b-install.sh - Install & configure Fail2ban (outside-focused)

Flags:
  --whitelist "<ip>[,<ip>...]"   Add one or more IPs/CIDRs to ignore (can repeat)
  --whitelist-file <path>        File with one IP/CIDR per line to ignore
  --enable-nginx                 Enable nginx jails (only if logs show real client IPs)
  --no-rfc1918                   Do NOT auto-whitelist RFC1918 ranges
  -h | --help                    Show this help

Examples:
  sudo ./f2b-install.sh --whitelist "203.0.113.7"
  sudo ./f2b-install.sh --whitelist-file /root/office-ips.txt --enable-nginx
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --whitelist)
      shift
      IFS=',' read -r -a _arr <<< "${1:-}"
      WHITELIST+=("${_arr[@]}")
      ;;
    --whitelist-file)
      shift
      WHITELIST_FILE="${1:-}"
      ;;
    --enable-nginx)
      ENABLE_NGINX="true"
      ;;
    --no-rfc1918)
      INCLUDE_RFC1918="false"
      ;;
    -h|--help)
      print_help; exit 0 ;;
    *)
      echo "Unknown flag: $1"; print_help; exit 1 ;;
  esac
  shift || true
done

# ------------ safety / deps ------------
if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2; exit 1
fi
export DEBIAN_FRONTEND=noninteractive

log="/var/log/fail2ban-setup.log"
exec 1> >(tee -a "$log") 2>&1
echo "[*] Log: $log"

echo "[*] Installing fail2ban..."
apt-get update -y
apt-get install -y fail2ban

# pick ban action
BANACTION="nftables-multiport"
command -v nft >/dev/null 2>&1 || BANACTION="iptables-multiport"
echo "[*] Using banaction: $BANACTION"

# ------------ build ignore list ------------
IGNORE_IPS=("127.0.0.1/8" "::1")
if [[ "$INCLUDE_RFC1918" == "true" ]]; then
  IGNORE_IPS+=("10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16")
fi

# from --whitelist
if (( ${#WHITELIST[@]} )); then
  IGNORE_IPS+=("${WHITELIST[@]}")
fi

# from --whitelist-file
if [[ -n "$WHITELIST_FILE" ]]; then
  if [[ ! -r "$WHITELIST_FILE" ]]; then
    echo "Whitelist file not readable: $WHITELIST_FILE" >&2; exit 1
  fi
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
    [[ -z "$line" ]] && continue
    IGNORE_IPS+=("$line")
  done < "$WHITELIST_FILE"
fi

# basic validation (warn only)
for ip in "${IGNORE_IPS[@]}"; do
  if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$|^([0-9a-fA-F:]+)(/[0-9]{1,3})?$ ]]; then
    echo "Warning: '$ip' doesn't look like an IP/CIDR. Continuing..." >&2
  fi
done

# ------------ write config ------------
mkdir -p /etc/fail2ban/jail.d /etc/fail2ban/filter.d

# Globals
cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = ${IGNORE_IPS[*]}
backend   = systemd
banaction = $BANACTION
bantime   = 1h
findtime  = 10m
maxretry  = 6
loglevel  = INFO
destemail = root@localhost
mta       = sendmail
EOF

# helper: does a TCP port listen?
has_tcp_port(){ ss -lnt | awk '{print $4}' | grep -q ":$1\$"; }

# SSH
if has_tcp_port 22 || systemctl list-unit-files | grep -q '^ssh\(d\)\?\.service'; then
  cat >/etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled   = true
port      = ssh
filter    = sshd
logpath   = /var/log/auth.log
maxretry  = 6
journalmatch = _COMM=sshd
EOF
fi

# Postfix
if systemctl list-unit-files | grep -q '^postfix\.service'; then
  cat >/etc/fail2ban/jail.d/postfix.local <<'EOF'
[postfix]
enabled  = true
filter   = postfix
port     = smtp,ssmtp,submission
logpath  = /var/log/mail.log
maxretry = 6
journalmatch = _SYSTEMD_UNIT=postfix.service
EOF
fi

# Dovecot
if systemctl list-unit-files | grep -q '^dovecot\.service'; then
  cat >/etc/fail2ban/jail.d/dovecot.local <<'EOF'
[dovecot]
enabled  = true
filter   = dovecot
port     = imap,imaps,pop3,pop3s
logpath  = /var/log/mail.log
maxretry = 6
journalmatch = _SYSTEMD_UNIT=dovecot.service
EOF
fi

# ManageSieve (4190)
cat >/etc/fail2ban/filter.d/dovecot-sieve.conf <<'EOF'
[Definition]
failregex = (?:dovecot: auth|managesieve-login): .*auth failed.*rip=<HOST>|.*authentication failure.*rip=<HOST>
ignoreregex =
EOF
cat >/etc/fail2ban/jail.d/sieve.local <<'EOF'
[sieve]
enabled  = true
port     = 4190
filter   = dovecot-sieve
logpath  = /var/log/mail.log
maxretry = 6
EOF

# coturn
if systemctl list-unit-files | grep -q '^coturn\.service'; then
  cat >/etc/fail2ban/filter.d/coturn.conf <<'EOF'
[Definition]
failregex = turnserver\[[0-9]+\]: (Wrong auth secret|not authorized|Cannot authenticate user|TLS handshake error|Fingerprint mismatch).*<HOST>
ignoreregex =
EOF
  cat >/etc/fail2ban/jail.d/coturn.local <<'EOF'
[coturn]
enabled   = true
filter    = coturn
port      = 3478,5349,49152:65535
protocol  = all
logpath   = /var/log/turnserver/turnserver.log
maxretry  = 8
findtime  = 10m
bantime   = 1h
EOF
fi

# nginx (optional)
cat >/etc/fail2ban/jail.d/nginx.optional.local <<EOF
[nginx-http-auth]
enabled = ${ENABLE_NGINX}
filter  = nginx-http-auth
port    = http,https
logpath = /var/log/nginx/error.log
maxretry = 6

[nginx-badbots]
enabled = ${ENABLE_NGINX}
filter  = nginx-badbots
port    = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

systemctl enable --now fail2ban
sleep 1
fail2ban-client status || true

echo
echo "[*] Done. ignoreip => ${IGNORE_IPS[*]}"
echo "[*] If you accidentally banned yourself: use console and run 'fail2ban-client unban --all'"
