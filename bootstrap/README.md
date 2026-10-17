# mycmd bootstrap Worker

Cloudflare Worker behind `https://get.mycmd.site/<project>/<recipe>[@channel|version]`.
Resolves versions from the git catalog and returns a shell installer (client downloads the artifact; Worker does not proxy tarball bytes).

Architecture: [`CONTEXT.md`](../CONTEXT.md), ADR [`docs/adr/how-to-selfhost-0001-ADR-mycmd-site-distro.md`](../docs/adr/how-to-selfhost-0001-ADR-mycmd-site-distro.md), generic playbook [`guides/how-to_distro_cloudflare_github.md`](../guides/how-to_distro_cloudflare_github.md).

## Local

```bash
cd bootstrap
cp .env.example .env   # optional; keep gitignored
npm install
npm run typecheck
npx wrangler dev
```

## Deploy

GitHub Actions: `.github/workflows/deploy-bootstrap.yml`  
Requires:
- Secret: `CLOUDFLARE_API_TOKEN`
- Variable: `CLOUDFLARE_ACCOUNT_ID`

Manual prove: Actions → **Deploy bootstrap Worker** → Run workflow (`workflow_dispatch`).

Maintainer Cloudflare wizard (local only): `pm/qwen-self-host/distro/configure-cloudflare-worker.sh`

## Public contract

```text
GET /<project>/<recipe>
GET /<project>/<recipe>@stable|beta|nightly|rc|<version>
```

- `GET /qwen3-8-flash-next/spark@beta` → installer (`beta` ↔ catalog `rc` → `0.0.1-rc1`)
- `GET /qwen3-8-flash-next/spark@0.0.1-rc1` → pin
- Legacy: `?channel=rc`, `?version=0.0.1-rc1`
- Unqualified path defaults to channel `rc`
- Errors → plain text, non-shell
