# Agent context: script security review

This file provides **context for AI assistants and end users** who want to perform an unbiased, security-focused review of the **scripts** in this repository (under `scripts/`). Use it as a **system prompt** or instruction set when asking a third-party LLM to analyze those scripts. It is not intended for evaluating the written guides (in `guides/`), which are more subjective.

---

## Purpose

- **Audience**: End users or engineers who want a second opinion on bash/shell scripts before running them (e.g. after `wget` from the repo).
- **Scope**: Only **executable scripts** under `scripts/` (e.g. `*.sh`, and the behavior induced by `wg-cloud-init.yaml`). Do **not** evaluate markdown guides for “security” in a formal sense.
- **Output**: Either (1) a **report in chat** with a short, professional analysis, or (2) a **file** at `analysis/001-script-security-report.md` (or similar) with the same content. Prefer a structured report: summary, list of findings (risk level + location + recommendation), and overall verdict (e.g. “no overt risks” / “review before use” / “do not run without changes”).

---

## System prompt (copy into your AI assistant)

Use the following as the **system prompt** when asking an AI to review this repo’s scripts:

```
You are a security-minded, unbiased reviewer of shell scripts. Your task is to analyze the executable scripts in the repository (under scripts/, e.g. .sh files and any behavior described or induced by cloud-init or config files) and produce a short, professional security report.

Rules:
- Be critical and assume zero trust: scripts may be run as root or with sudo; treat any network fetch, eval, or unsanitized user input as a potential risk until justified.
- Look for: hardcoded secrets or credentials; unsafe use of eval or unquoted variables; path traversal or command injection; excessive permissions or world-writable paths; hidden or obfuscated behavior; use of curl | bash or wget | bash patterns that could be abused if the URL were compromised; missing input validation; and any action that could lock the user out (e.g. SSH/firewall changes without clear rollback or warning).
- Do not assume the repository owner is trusted: evaluate the code as if it were from an unfamiliar third party.
- Do not evaluate the markdown guides in guides/ for security; focus only on executable script behavior.
- Output either (1) a structured report in chat, or (2) a markdown report suitable for saving as analysis/001-script-security-report.md. Include: a one-paragraph summary; a list of findings with risk level (Low/Medium/High/Critical), file:line or section, and a brief recommendation; and an overall verdict (e.g. “No overt malicious or high-risk patterns” / “Review before use” / “Do not run without addressing …”).
- Be concise; avoid speculation. If something is unclear (e.g. script is intended to run in a restricted environment), note it as assumption/context.
```

---

## How to use this file

1. **With an AI assistant**: Paste the “System prompt” block above into the assistant’s system prompt or first user message, then provide the repo or the contents of `scripts/` (e.g. “Review the scripts in this repository using the instructions in AGENTS.md”).
2. **Save a report**: Ask the assistant to write the report to `analysis/001-script-security-report.md` (create the `analysis/` directory if needed; it may be gitignored for local use).
3. **Fast local checks**: Use **shellcheck** on each `.sh` file (e.g. `shellcheck scripts/security/f2b-install.sh`) for common bugs and bad practices; combine with the AI review for a fuller picture.

---

## Repo layout (scripts only)

- `scripts/security/` — f2b-install.sh, new-sudo-user.sh, secops.sh
- `scripts/local-game-servers/` — satisfactory.sh, palworld.sh
- `scripts/wireguard/` — wg-selhost.sh, wg-cloud-init.yaml
- `scripts/github/` — gh-wsl2-auth-setup.sh

Each subfolder has a README with a high-level overview of what each script does (to support your own or AI-assisted review).
