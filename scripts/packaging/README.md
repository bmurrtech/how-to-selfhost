# Build recipe artifacts for get.mycmd.site / GitHub Releases

```bash
bash scripts/packaging/package-recipe.sh 0.0.1-rc1
```

Writes `dist/packaging/qwen3-8-flash-next-spark-<version>.tar.gz` + `.sha256` (gitignored).

Then (human): create the GitHub Release, paste sha256 into `catalog/recipes.json`, merge.

Architecture: [`CONTEXT.md`](../../CONTEXT.md).
