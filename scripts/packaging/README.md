# Build recipe artifacts for get.mycmd.site / GitHub Releases

```bash
# Default: qwen3-8-flash-next/spark @ 0.0.1-rc2
bash scripts/packaging/package-recipe.sh

# Explicit recipe + version
bash scripts/packaging/package-recipe.sh patching/windows 0.1.0-rc1
```

Writes `dist/packaging/<artifact>.tar.gz` + `.sha256` (gitignored).

Then (human): create the GitHub Release, paste sha256 into `catalog/recipes.json`, merge/push catalog.

| Recipe ID | Source tree | Suggested release tag |
|-----------|-------------|------------------------|
| `qwen3-8-flash-next/spark` | `scripts/local-ai/` (spark only) | `v<version>` |
| `qwen3-8-flash-next/rtx-6000-pro` | `scripts/local-ai/` (rtx only) | `v<version>` (same tag may hold both local-ai assets) |
| `security/vps-baseline` | `scripts/security/` (excludes `archive/`) | `security-vps-baseline-v<version>` |
| `patching/{windows,macos,linux}` | `scripts/patching/` (shared artifact) | `patching-devtools-v<version>` |

Packaged local-ai Justfile includes: `doctor`/`check`, `config`, `probe`, `benchmark`, `benchmark-load`, `gpu`, `logs`, `snapshot`, lifecycle.

Architecture: [`CONTEXT.md`](../../CONTEXT.md). Changelog: [`CHANGELOG.md`](../../CHANGELOG.md).
