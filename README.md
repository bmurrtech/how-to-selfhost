![infra](https://i.imgur.com/shQaQeR.png)

## Why This Exists — Digital Freedom, For All
To give you back control over your digital life, empowering you to learn, host, and play freely.

- **Open knowledge is a human right** — We have the moral responsibility to resist digital tyranny. "We hold these truths to be self-evident, that all men are created equal, that they are endowed by their Creator with certain unalienable Rights, that among these are Life, Liberty and the pursuit of Happiness." When "any Form of Government [Big Tech] becomes destructive of these ends, it is the Right of the People to alter or to abolish it, and to institute new Government..." (Declaration of Independence).
- **A stand against digital tyranny** — Big tech erodes privacy, treats you as the product. Open source restores agency.
- **Privacy-by-design** — Host your own services securely and simply, using your hardware or any VPS, no vendor lock-in.
- **Practical tools for real people** — Wizard-style, modular guides/scripted installs make secure self-hosting and game servers accessible to all.
- **Security-first, not afterthought** — Defaults harden SSH, block open ports, and recommend free enterprise solutions (like WireGuard, local-first setup, and role-based access).
- **Help your fellow human** — By using, contributing to, or sharing these tools, you enable digital freedom for yourself and others.


## Homelab How-to & More

- [ULTIMATE Proxmox Hypervisor](guides/how-to_ultimate_proxmox.md)
- [ULITMATE Self-Hosted Gamer Server](guides/how-to_game_servers.md)
- [Remotely Access Your Servers via Cloudflare](guides/how-to_cloudflare.md)
- [PfSense NG-FW Configuration with VLANS](guides/how-to_pfsense.md)
- [Self-hosted, Security-hardened Ghost Blog Site](guides/how-to_ghost_blog.md)
- [Free SASE Solution Using CloudFlare Zero-trust Tunnels](guides/how-to_cloudflare.md)
- [How-to Create a Flux Node on Proxmox](guides/how-to_flux_proxmox_node.md)
- [How-to Setup Kemp Load-balancer](guides/how-to_kemp_loadmaster.md)
- [How-to Make a 24-7 Youtube Livestream](guides/how-to_24-7_livestream.md)

See **[guides/README.md](guides/README.md)** for a full glossary and status of each guide.

## Scripts: trust-but-verify mindset

Nowadays, zero-trust mindset might be better. To promote public trust:

- Read each script before running it (especially when using `curl | bash` or `wget`).
- Prefer downloading the raw file, reviewing it locally, then executing with appropriate privileges.
- Optionally use **AGENTS.md** in this repo as a system prompt for an AI assistant to perform an unbiased, security-focused review of scripts and produce a short report (see [AGENTS.md](AGENTS.md)).

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)  
This repository is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE).

### License Permissions & Restrictions (Summary)
| Use Case                              | Permitted | Notes/Conditions                                                        |
|----------------------------------------|-----------|-------------------------------------------------------------------------|
| Private/internal use                   | ✔️        | No restrictions                                                         |
| Modify for own private use             | ✔️        |                                                                        |
| Share/distribute (unmodified)          | ✔️        | Must include AGPL license and source                                    |
| Distribute with modifications          | ✔️        | Must release source code under AGPL-3.0                                 |
| Provide as SaaS/network service        | ✔️        | Network users must get complete source                                  |
| Keep modifications private             | ✔️        | Disclosure required only if distributed or served over network          |
| Closed/proprietary forks               | ❌        | All distributed/network use requires full source disclosure             |
| Restricting access to source code      | ❌        | Source must be public for users                                         |
| Sub-licensing under restrictive terms  | ❌        | Must retain AGPL-3.0 copyleft                                           |
| Hosted service without source sharing  | ❌        | Must provide source to all network users                                |
