#!/usr/bin/env bash
# doctor.sh — read-only host probe (sshd / UFW / fail2ban). Does not mutate.
set -euo pipefail

pass() { printf '[PASS] %-18s %s\n' "$1" "${2:-}"; }
warn() { printf '[WARN] %-18s %s\n' "$1" "${2:-}"; }
fail() { printf '[FAIL] %-18s %s\n' "$1" "${2:-}"; }
skip() { printf '[SKIP] %-18s %s\n' "$1" "${2:-}"; }

echo "security / vps-baseline — doctor"
echo

# --- sshd ---
if command -v sshd >/dev/null 2>&1 || [[ -x /usr/sbin/sshd ]]; then
	pass "sshd binary" "present"
else
	fail "sshd binary" "not found"
fi

if command -v systemctl >/dev/null 2>&1; then
	if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
		pass "sshd service" "active"
	else
		warn "sshd service" "not active (or unit name unknown)"
	fi
else
	skip "sshd service" "systemctl missing"
fi

if [[ -r /etc/ssh/sshd_config ]]; then
	root_login="$(sshd -T 2>/dev/null | awk '/^permitrootlogin / {print $2; exit}' || true)"
	pw_auth="$(sshd -T 2>/dev/null | awk '/^passwordauthentication / {print $2; exit}' || true)"
	if [[ -n "$root_login" || -n "$pw_auth" ]]; then
		pass "sshd config" "PermitRootLogin=${root_login:-?} PasswordAuthentication=${pw_auth:-?}"
	else
		warn "sshd config" "present but sshd -T unavailable (need root?)"
	fi
else
	warn "sshd config" "/etc/ssh/sshd_config unreadable"
fi

# --- UFW ---
if command -v ufw >/dev/null 2>&1; then
	ufw_status="$(ufw status 2>/dev/null | head -1 || true)"
	pass "ufw" "${ufw_status:-installed}"
else
	fail "ufw" "not installed (just harden)"
fi

# --- fail2ban ---
if command -v fail2ban-client >/dev/null 2>&1; then
	if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet fail2ban 2>/dev/null; then
		pass "fail2ban" "active"
	else
		warn "fail2ban" "installed but not active"
	fi
else
	fail "fail2ban" "not installed (just f2b)"
fi

# --- IPv6 sysctl (informational; harden disables it) ---
if [[ -r /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; then
	v6="$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo '?')"
	if [[ "$v6" == "1" ]]; then
		pass "IPv6" "disabled (sysctl)"
	else
		warn "IPv6" "enabled (harden sets disable_ipv6=1)"
	fi
else
	skip "IPv6" "sysctl node missing"
fi

echo
echo "Read-only probe done. Mutating recipes: just user | just harden | just f2b"
exit 0
