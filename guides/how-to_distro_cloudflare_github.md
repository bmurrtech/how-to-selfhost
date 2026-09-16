# Universal Cloudflare Worker distribution gateway

Versioned install recipes behind one HTTPS hostname. A Cloudflare Worker resolves the URL and returns a small bootstrap script; the client downloads the artifact from GitHub Releases (or another store).

**Scope:** installer scripts and recipe tarballs **under 2 GiB** as GitHub Release assets (or any direct-download URL). If an artifact is larger than 2 GiB, put it on **Cloudflare R2** (or similar) and keep the Worker as resolver only. R2 wiring is out of scope here.

**How to use this guide:** finish [Prerequisites](#prerequisites), ship a [Worker for one repository](#worker-for-one-repository), then optionally [graduate to a distribution gateway](#graduate-to-a-distribution-gateway) that serves many repos from the same hostname.

---

## Glossary

| Term | What it is | Jump |
| --- | --- | --- |
| Distribution hostname | Public `get.` (or similar) host users curl | [Prerequisites](#prerequisites) |
| Custom Domain | Cloudflare binding that makes the Worker the origin for that hostname | [Attach the Custom Domain](#attach-the-custom-domain) |
| Infra gate | Post-deploy proof: DNS + TLS + hostname → Worker (`curl -i`) | [Confirm DNS, TLS, and Worker routing](#confirm-dns-tls-and-worker-routing) |
| Worker | Cloudflare script that parses the path and returns the installer | [Worker for one repository](#worker-for-one-repository) |
| Catalog / registry | Config that maps project + recipe + channel → immutable release + artifact | [Registry](#registry) |
| Project / recipe | Public path segments: `/<project>/<recipe>` | [URL contract](#url-contract) |
| Channel | Mutable name (`stable`, `beta`, `nightly`) pointing at an immutable version | [URL contract](#url-contract) |
| Immutable version | Exact release id (e.g. `1.4.2`) that must not silently change | [URL contract](#url-contract) |
| Artifact | Tarball + checksum on GitHub Releases (≤2 GiB on this path) | [Release and artifact contract](#release-and-artifact-contract) |
| Bootstrap installer | Shell the Worker returns; downloads, verifies, extracts | [What the Worker returns](#what-the-worker-returns) |
| Package repository | Repo that builds and publishes recipe tarballs | [Package repo release workflow](#package-repo-release-workflow) |
| Distribution repository | Repo that owns Worker source, registry, and Cloudflare deploy CI | [Graduate to a distribution gateway](#graduate-to-a-distribution-gateway) |
| Distribution gateway | One Worker + one hostname serving many projects/repos via the registry | [Graduate to a distribution gateway](#graduate-to-a-distribution-gateway) |

---

## URL contract

```text
/<project>/<recipe>
/<project>/<recipe>@stable
/<project>/<recipe>@beta
/<project>/<recipe>@nightly
/<project>/<recipe>@<immutable-version>
```

```bash
curl -fsSL https://get.example.com/project-a/recipe-x | sh
curl -fsSL https://get.example.com/project-a/recipe-x@beta | sh
curl -fsSL https://get.example.com/project-a/recipe-x@1.4.2 | sh
```

Channels are mutable aliases. Versions are immutable.

```text
stable   -> current recommended production release
beta     -> current prerelease candidate
nightly  -> current automated development build
1.4.2    -> always that exact release
```

Store an explicit immutable target behind each channel. Do not treat `@nightly` as “whatever GitHub marked latest.”

Once `stable` exists, unqualified `/project-a/recipe-x` should mean `@stable`.

A public URL names a **project** and **recipe**. The registry chooses which GitHub repository, release, artifact, and checksum satisfy that request. The URL does not have to match the GitHub repo name.

---

## Prerequisites

Do all of this before writing Worker code or asking an agent to implement CI. You need account ownership and secret handling here; agents should get **identifiers and secret names**, not token values.

### Checklist

| # | Task | Done when |
| --- | --- | --- |
| 1 | GitHub account + Cloudflare account | You can sign in to both |
| 2 | Password manager (or equivalent) ready | You have a place for the API token |
| 3 | Domain chosen | Existing zone subdomain (`get.example.com`) or a dedicated domain |
| 4 | Domain added to Cloudflare; nameservers at registrar point to Cloudflare | Zone status **Active** |
| 5 | Distribution hostname chosen | e.g. `get.example.com` — **no** manual CNAME yet if you will use a Worker Custom Domain |
| 6 | GitHub repository created for the Worker | Empty or scaffold repo; Actions enabled |
| 7 | Cloudflare Account ID recorded | Saved with your deploy notes |
| 8 | Cloudflare API token created, scoped, saved | Secret in password manager; shown only once |
| 9 | GitHub Actions secrets set | `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` |
| 10 | Actions permissions left restricted | Default read contents/packages; no blanket write for Cloudflare’s sake |
| 11 | (Optional) `production` environment | Credentials only on that environment if you want reviewers / branch locks |

### Steps

1. **Pick the domain.** Use an existing domain and a `get.` hostname, or buy a dedicated one. Registration itself is out of scope.

2. **Add the zone to Cloudflare** and switch the registrar’s authoritative nameservers to the ones Cloudflare assigns. Wait until the zone is **Active**.

   ```text
   registrar  →  Cloudflare nameservers  →  Active zone
   ```

3. **Record zone + hostname.** Do not create a CNAME for the distribution hostname if you plan a Worker **Custom Domain**. Cloudflare creates DNS and TLS when you attach the Custom Domain. A conflicting CNAME blocks that attach.

   ```text
   Zone: example.com
   Hostname: get.example.com
   ```

4. **Create or choose the GitHub repo** that will hold Worker source and deploy workflows. Enable Actions. Under Settings → Actions → General → Workflow permissions, keep the restricted default (read repository contents and packages). Leave “create and approve pull requests” off unless a workflow needs it.

5. **Copy the Cloudflare Account ID** for the account that will own the Worker. Keep it with the hostname and Worker name in your notes. It is an identifier, not a password.

6. **Create the API token.** Cloudflare → API Tokens → Create Token → start from template **Edit Cloudflare Workers** (Cloudflare’s recommended start for Wrangler / GitHub Actions).

   That template grants:

   | Scope | Permission | Access |
   | --- | --- | --- |
   | Zone | Workers Routes | Edit |
   | Account | Workers Scripts | Edit |
   | Account | Workers KV Storage | Edit |
   | Account | Workers Tail | Read |
   | Account | Workers R2 Storage | Edit |
   | Account | Account Settings | Read |
   | User | User Details | Read |
   | User | User Memberships | Read |

   Broader than a minimal deploy needs. Start here so bootstrap does not fail on a missing permission; trim later.

7. **Narrow token resources.** Account → specific account with the Worker. Zone → specific zone (`example.com`). Do not leave “all accounts / all zones” unless that is intentional.

   `Workers Scripts` is account-level. The token is not bound to one script name. Pair it with a dedicated deploy repo and tight GitHub write access.

8. **Capture the token secret immediately** (Cloudflare shows it once):

   1. Copy it.
   2. Save it in the password manager (`Cloudflare — <worker-name> GitHub CI`).
   3. Note which GitHub repo will use it.
   4. Do not put it in source, Wrangler config, committed `.env`, issues, PRs, READMEs, or chat.

   If you lose it, create a new token and revoke the old one. You can edit permissions on an existing token later; you cannot redisplay the secret.

9. **Add GitHub Actions secrets** (Settings → Secrets and variables → Actions):

   ```text
   CLOUDFLARE_API_TOKEN    = <token secret>
   CLOUDFLARE_ACCOUNT_ID   = <account id>
   ```

   Cloudflare’s Actions docs use these names. You may store the Account ID as a GitHub **variable** instead; two secrets is the simplest baseline. Workflows read `secrets.CLOUDFLARE_API_TOKEN` and `secrets.CLOUDFLARE_ACCOUNT_ID`.

10. **Optional:** create environment `production`, put credentials there, restrict deploys to `main`, add required reviewers if you want them.

### Handoff note (for an implementation agent)

```text
Cloudflare account: <name>
Cloudflare Account ID: <id or "in GitHub secret">
Zone: example.com
Hostname: get.example.com
Worker name: <e.g. project-a-bootstrap>
GitHub repo: owner/<repo>
Default branch: main
Secrets: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID = yes
First project / recipe / channels: …
```

### STOP — prerequisites

Do not start Worker implementation until the checklist above is complete and the zone is Active.

---

## Worker for one repository

Start here. One GitHub repo, one Worker, one hostname, one project path. Prove install end-to-end before designing multi-repo routing.

```text
User
  |
  v
get.example.com
  |
  v
Cloudflare Custom Domain
  |
  v
project-a-bootstrap   ← Worker (name it after this first project if you want)
  |
  v
catalog in this repo
  |
  v
this repo’s GitHub Releases
  |
  v
artifact + checksum  (client downloads; Worker does not proxy bytes)
```

The Worker is the control plane. It resolves project, recipe, channel/version, artifact URL, and checksum. The artifact store serves the tarball.

### Steps

1. **Name the Worker** for this first ship (example: `project-a-bootstrap`). Put that name in Wrangler config and keep it stable. Renaming an npm package must not spawn a second Worker by accident.

2. **Implement against the URL contract** in this same repository (or a thin sibling if you already split source — still one logical product for v1):

   - Worker source + Wrangler config (`wrangler.jsonc` preferred for new projects)
   - Catalog / registry with the first project + recipe
   - Path parser, channel resolver, artifact resolver
   - `/health`, clear 400/404/5xx text errors
   - Validate workflow (no Cloudflare credentials)
   - Deploy workflow (`wrangler deploy` via `cloudflare/wrangler-action`, `contents: read`)
   - Smoke: `/health` + one install URL after deploy
   - Operator README

3. **Prefer a Custom Domain** over a traditional Worker Route. Custom Domain: Worker **is** the origin. Worker Route: Worker sits in front of another origin. Cloudflare recommends Custom Domains when the Worker is the app origin.

### Attach the Custom Domain

1. Deploy the Worker at least once (Actions or local Wrangler with the same credentials pattern).
2. Workers & Pages → your Worker → Settings → Domains & Routes → Add → Custom Domain → `get.example.com`.
3. Prefer declaring the Custom Domain in Wrangler (`custom_domain: true`) so git holds the hostname binding.
4. If attach fails on a conflicting CNAME, remove or migrate that DNS record, then retry. Do not invent a random hostname to dodge the conflict.

### Confirm DNS, TLS, and Worker routing

After GitHub Actions has deployed the Worker and the Custom Domain is attached, prove the public hostname reaches the Worker. A successful `ping` or an A/AAAA that lands on a Cloudflare edge address only shows DNS resolution. It does not prove TLS, Custom Domain routing, or resolver logic.

1. **Health over HTTPS**

   ```bash
   curl -i https://get.example.com/health
   ```

   Expected (shape):

   ```text
   HTTP/2 200
   ...
   <worker health body, e.g. "... ok">
   ```

   Use `/` if your Worker serves health there instead of `/health`.

2. **Recipe resolver (same hostname)**

   ```bash
   curl -i "https://get.example.com/project-a/recipe-x@beta"
   ```

   Before the catalog has a real artifact checksum, a controlled refusal is a pass for this gate — for example HTTP `503` with a clear “checksum / sha256 not published yet” (or equivalent) body. That shows:

   ```text
   DNS → TLS → Custom Domain → Worker → catalog/resolver
   ```

   while correctly refusing install until the release + checksum exist.

   If the catalog is already complete, expect HTTP `200` and a shell installer (`Content-Type` typically `text/x-shellscript`). Do not pipe to `sh` until you have reviewed it.

3. **Mark the infra gate** only when both curls behave as expected:

   ```text
   [x] Worker deploys through GitHub Actions
   [x] Worker reachable
   [x] Custom Domain attached
   [x] DNS resolves
   [x] TLS/HTTPS works
   [x] Public hostname reaches Worker
   [ ] workers.dev disposition decided
   ```

4. **Disable `workers.dev`** for this Worker in the Cloudflare dashboard (or equivalent), then set in Wrangler so a later deploy does not turn it back on:

   ```toml
   workers_dev = false
   ```

   (Same flag in `wrangler.jsonc` if that is your config format.) Redeploy once so the setting sticks.

### STOP — infra gate

Do not treat DNS alone as “Worker routing complete.” Finish the two `curl -i` checks (and `workers_dev = false`) before moving on to publishing artifacts or a full install.

Next critical path after this gate: build and inspect the immutable release artifact → publish tarball + checksum on GitHub Releases → put the real SHA in the catalog → deploy/merge the catalog change → only then run the public installer end-to-end on a clean machine.

### What the Worker returns

```text
GET /project-a/recipe-x@beta
        |
        v
Worker validates + resolves channel → immutable version + artifact URL/sha256
        |
        v
small bootstrap shell
        |
        v
client downloads from GitHub Releases (or later R2)
```

Do not turn the Worker into a package CDN. Swapping the artifact backend later should not change the public URL.

Minimum paths:

```text
/health
/<project>/<recipe>
/<project>/<recipe>@stable|beta|nightly|<version>
```

| Case | Status |
| --- | --- |
| Valid target | 200 |
| Unknown project, recipe, channel, or version | 404 |
| Malformed path | 400 |
| Catalog/config failure | 500/503 |

Do not silently fall back from `@beta` to `@stable`. Missing channel → fail clearly.

### Release and artifact contract

Publish immutable assets, e.g.:

```text
project-a-recipe-x-1.4.2.tar.gz
project-a-recipe-x-1.4.2.tar.gz.sha256
```

Bundle may include `mise.toml`, `Justfile`, install scripts, config, compose, README, manifest. Stay under **2 GiB** for this GitHub Releases design.

Installer flow:

```text
resolve → download → verify checksum/signature → extract → readiness → setup → deploy → health
```

`@beta` must resolve to a concrete artifact name before install runs.

### Registry

Even for one repo, keep mappings in a catalog file instead of scattering GitHub URLs through Worker code.

```yaml
schema: 1
project: project-a
source:
  provider: github
  owner: example
  repository: project-a   # may differ from public project name
recipes:
  recipe-x:
    channels:
      stable:
        version: 1.4.2
      beta:
        version: 1.5.0-beta.3
      nightly:
        version: 2026.09.14+abc1234
```

Keep separate: project, repository, recipe, channel, immutable version, artifact, checksum.

### Package repo release workflow

For the single-repo start, release CI and Worker deploy may live in the same GitHub repository. Flow:

```text
tag/release → build bundle → test → tarball → checksum → publish release asset → update catalog channel pointer → (Worker already reads catalog; no DNS change)
```

New recipe versions must not require Cloudflare or DNS edits.

### Worker CI (validate + deploy)

**Validate** (PR / push): deps, catalog schema, Worker tests, channel resolution. No Cloudflare credentials.

**Deploy** (push to main or explicit policy): validate → build → `wrangler deploy` → run the [Confirm DNS, TLS, and Worker routing](#confirm-dns-tls-and-worker-routing) curls against the public hostname. Pin third-party actions to full commit SHAs when you harden supply chain.

### STOP — one path green

Infra gate ([above](#confirm-dns-tls-and-worker-routing)) must already pass. Then prove one **full** install on a clean machine before `@beta` / `@nightly` sprawl or a second project:

```text
channel → immutable version
bootstrap returned
artifact downloaded + checksum OK
extract + post-install checks OK
```

Then add channels in order: default/stable → `@beta` (different immutable when expected) → `@nightly` (print resolved version + checksum; treat as disposable). Then pin `@1.4.2` and confirm it never silently tracks a newer build.

### Optional token harden

After deploys work, you can trim the API token toward Account → Workers Scripts → Write (Custom Domain attach uses that). Traditional Worker Routes also need Zone → Workers Routes → Write. Do not grant DNS Write, SSL Write, Account administrator, or a Global API key unless something else needs them.

### Recovery (single-repo and later)

| Problem | Fix |
| --- | --- |
| Auth works; deploy or domain attach fails | Edit token permissions / account / zone resources. No Global API key. |
| Wrong Worker name created | Point Wrangler, Custom Domain, and workflow at the intended Worker; retire the accident. |
| Hostname on wrong Worker | Move Domains & Routes; do not redo nameservers. |
| Conflicting CNAME | Remove/migrate record, then attach Custom Domain. |
| Lost API token secret | New token → password manager → replace GitHub secret → test deploy → revoke old. |

### Definition of done (one repo)

| Test | Result |
| --- | --- |
| Zone Active; Custom Domain on `get.<domain>` | Pass |
| Worker deployed by Actions; credentials not in git | Pass |
| Token scoped and stored in password manager | Pass |
| Public `curl -i` health + recipe resolver checks pass | Pass |
| `workers_dev = false` in Wrangler; workers.dev disabled | Pass |
| `/health` over HTTPS | Pass |
| First channel URL installs; pin `@version` is deterministic | Pass |
| `@beta` / `@nightly` independent when you add them | Pass |
| Checksum verified before extract/execute | Pass |
| New release ≠ DNS change | Pass |

---

## Graduate to a distribution gateway

When a second product needs the same `get.` hostname, do not add DNS records or a second Cloudflare zone. Grow into one **distribution-gateway** Worker whose registry points at many GitHub repositories.

```text
                     get.example.com
                            |
                            v
                 distribution-gateway
                            |
                            v
                       registry
           +----------------+----------------+
           v                v                v
        project-a        project-b        project-c
           |                |                |
           v                v                v
      GitHub Repo A    GitHub Repo B    GitHub Repo C
           |                |                |
           v                v                v
              immutable releases + checksums
```

### When to graduate

Move when you need a second public project on the same hostname, or when you want Cloudflare deploy credentials out of package repos. A different domain alone is not a reason for a second Worker.

### Steps

1. **Create (or rename into) a distribution repository** that owns:

   ```text
   Worker implementation
   routing registry
   schemas + validation
   Cloudflare deploy workflow
   distribution docs
   ```

   Example layout:

   ```text
   distribution-gateway/
   ├── worker/
   ├── registry/
   │   ├── project-a.yaml
   │   ├── project-b.yaml
   │   └── project-c.yaml
   ├── schemas/
   ├── tests/
   ├── wrangler.jsonc
   └── .github/workflows/
       ├── validate.yml
       └── deploy-worker.yml
   ```

2. **Rename or create Worker `distribution-gateway`** (or keep the existing Worker name if traffic already uses it — then migrate config, do not fork hostnames). Attach the same Custom Domain. Paths for every project hit this one Worker.

3. **Move the catalog** into registry documents keyed by project. Public path `/project-b/server` can map to `owner/other-repo` without matching names.

4. **Move `CLOUDFLARE_API_TOKEN` to the distribution repo only.** Package repos publish artifacts and open PRs (or automation) that update registry channel pointers. They must not deploy `get.example.com/*`.

5. **Add repo two via registry only:** compliant artifact → registry entry → PR → validate → merge → Worker deploy. No DNS change. No new hostname. No Cloudflare token in the package repo.

6. **Add repo three the same way.** If that requires a new Worker or DNS edit only because GitHub repos differ, the abstraction leaked — fix the registry, not the zone.

### Credential ownership

Cloudflare credentials belong on the distribution control plane. A compromised package workflow must not deploy the public installer hostname.

If you use org-level secrets later, grant **selected repositories** only. Start with repo or environment secrets on the distribution repo.

### Extra domains (optional)

Cloudflare can attach multiple Custom Domains to one Worker.

| Model | Use when |
| --- | --- |
| Same Worker, second hostname | Same operator, registry, security boundary, deploy lifecycle |
| Separate Worker | Different team, credentials, registry, availability, or Cloudflare account |

New domain human path: purchase → Cloudflare zone → nameservers → Active → reuse Worker or create dedicated → attach Custom Domain. Same account: add the zone to the token’s zone resources if needed. Different account: separate token and clear secret names.

### Definition of done (gateway)

| Test | Result |
| --- | --- |
| Second GitHub repo served on the same hostname/Worker | Pass |
| Third repo: registry + PR only; no DNS | Pass |
| Package repos lack Cloudflare deploy credentials | Pass |
| New GitHub repo ≠ DNS change; new artifact backend ≠ curl URL change | Pass |

Only a genuinely new public hostname should need Cloudflare domain-level setup.

---

## Naming reference

```text
Hostname:     get.example.com
First Worker: project-a-bootstrap   (single-repo start)
Later Worker: distribution-gateway  (multi-repo)
CI secrets:   CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN
Channels:     stable, beta, nightly
```

Keep infrastructure names distinct from package/project names.
