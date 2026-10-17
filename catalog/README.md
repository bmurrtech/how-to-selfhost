# Recipe catalog (git-controlled resolver)

Maps recipe ID → channel → version → artifact URL + sha256.

Consumed by the `mycmd-bootstrap` Worker (`CATALOG_URL` in `bootstrap/wrangler.toml`).

After publishing a GitHub Release, update the matching `sha256` (never leave `REPLACE_*` live) and merge to `main`. Package releases must not redeploy Cloudflare.

See [`CONTEXT.md`](../CONTEXT.md) and [`docs/adr/how-to-selfhost-0001-ADR-mycmd-site-distro.md`](../docs/adr/how-to-selfhost-0001-ADR-mycmd-site-distro.md).
