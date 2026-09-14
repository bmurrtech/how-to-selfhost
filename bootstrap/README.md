# mycmd bootstrap Worker

Cloudflare Worker behind `https://get.mycmd.site/<family>/<target>`.
Resolves versions from the git catalog and returns a shell installer.

Architecture: [`CONTEXT.md`](../CONTEXT.md), ADR [`docs/ADRs/how-to-selfhost-0001-ADR-mycmd-site-distro.md`](../docs/ADRs/how-to-selfhost-0001-ADR-mycmd-site-distro.md).

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

- `GET /qwen3-8-flash-next/spark` → installer (default channel from catalog; use `?channel=rc`)
- `GET /qwen3-8-flash-next/spark?version=0.0.1-rc1` → pin
- Errors → plain text, non-shell
