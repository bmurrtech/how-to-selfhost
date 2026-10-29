export interface Env {
  CATALOG_URL: string;
  INSTALL_ROOT_DEFAULT: string;
}

interface CatalogVersion {
  artifact: string;
  url: string;
  sha256: string;
}

interface CatalogRecipe {
  channels?: Record<string, string>;
  versions: Record<string, CatalogVersion>;
}

interface Catalog {
  schema: number;
  recipes: Record<string, CatalogRecipe>;
}

const PLACEHOLDER_SHA = /^(REPLACE_|PENDING|TODO|CHANGE_ME)/i;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return text("method not allowed", 405);
    }

    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/health") {
      return text("mycmd-bootstrap ok\n", 200);
    }

    const parsed = parseInstallPath(url.pathname);
    if (!parsed) {
      return text(
        "usage: GET /<project>/<recipe>[@stable|beta|nightly|rc|<version>] (also ?channel= / ?version=)\n",
        400,
      );
    }

    let catalog: Catalog;
    try {
      catalog = await fetchCatalog(env.CATALOG_URL);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "catalog fetch failed";
      return text(`catalog error: ${msg}\n`, 502);
    }

    const { recipeId } = parsed;
    const recipe = catalog.recipes[recipeId];
    if (!recipe) {
      return text(`unknown recipe: ${recipeId}\n`, 404);
    }

    const versionParam = url.searchParams.get("version");
    const channelParam = url.searchParams.get("channel");
    const version = resolveVersion(recipe, {
      versionParam,
      pathRef: parsed.pathRef,
      channelParam,
    });
    if (!version.ok) {
      return text(`${version.error}\n`, version.status);
    }

    const entry = recipe.versions[version.value];
    if (!entry) {
      return text(`version not in catalog: ${version.value}\n`, 404);
    }

    if (!entry.sha256 || PLACEHOLDER_SHA.test(entry.sha256)) {
      return text(
        `catalog sha256 for ${recipeId}@${version.value} is not published yet\n`,
        503,
      );
    }

    if (!entry.url || !entry.artifact) {
      return text(`catalog entry incomplete for ${recipeId}@${version.value}\n`, 503);
    }

    const installRoot = env.INSTALL_ROOT_DEFAULT || "$HOME/mycmd";
    const script = buildInstaller({
      recipeId,
      version: version.value,
      url: entry.url,
      sha256: entry.sha256,
      artifact: entry.artifact,
      installRoot,
    });

    if (request.method === "HEAD") {
      return new Response(null, {
        status: 200,
        headers: {
          "content-type": "text/x-shellscript; charset=utf-8",
          "cache-control": "no-store",
        },
      });
    }

    return new Response(script, {
      status: 200,
      headers: {
        "content-type": "text/x-shellscript; charset=utf-8",
        "cache-control": "no-store",
        "x-mycmd-recipe": recipeId,
        "x-mycmd-version": version.value,
      },
    });
  },
};

function text(body: string, status: number): Response {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

/** Path grammar: /<project>/<recipe>[@<channel|version>] */
function parseInstallPath(
  pathname: string,
): { recipeId: string; pathRef: string | null } | null {
  const parts = pathname.replace(/^\/+|\/+$/g, "").split("/").filter(Boolean);
  if (parts.length !== 2) return null;
  const [project, recipeAndRef] = parts;
  if (!project || !recipeAndRef) return null;
  if (!/^[\w.-]+$/.test(project)) return null;

  const at = recipeAndRef.indexOf("@");
  let recipe: string;
  let pathRef: string | null = null;
  if (at === -1) {
    recipe = recipeAndRef;
  } else if (at === 0) {
    return null;
  } else {
    recipe = recipeAndRef.slice(0, at);
    pathRef = recipeAndRef.slice(at + 1);
    if (!pathRef || !/^[\w.+\-]+$/.test(pathRef)) return null;
  }
  if (!/^[\w.-]+$/.test(recipe)) return null;
  return { recipeId: `${project}/${recipe}`, pathRef };
}

async function fetchCatalog(catalogUrl: string): Promise<Catalog> {
  const res = await fetch(catalogUrl, {
    headers: { accept: "application/json" },
    cf: { cacheTtl: 60, cacheEverything: true },
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} from catalog`);
  }
  const data = (await res.json()) as Catalog;
  if (!data?.recipes || typeof data.recipes !== "object") {
    throw new Error("invalid catalog shape");
  }
  return data;
}

/** rc and beta are aliases of each other for channel lookup. */
function channelLookupNames(channel: string): string[] {
  if (channel === "rc" || channel === "beta") {
    return channel === "beta" ? ["beta", "rc"] : ["rc", "beta"];
  }
  return [channel];
}

function resolveChannel(
  recipe: CatalogRecipe,
  channel: string,
): string | null {
  for (const name of channelLookupNames(channel)) {
    const pinned = recipe.channels?.[name];
    if (pinned) return pinned;
  }
  return null;
}

/**
 * Priority: ?version= → path @ref (channel then version) → ?channel= → default rc.
 * Path @ref tries channel aliases first, then immutable versions.
 */
function resolveVersion(
  recipe: CatalogRecipe,
  args: {
    versionParam: string | null;
    pathRef: string | null;
    channelParam: string | null;
  },
): { ok: true; value: string } | { ok: false; error: string; status: number } {
  if (args.versionParam) {
    if (!recipe.versions[args.versionParam]) {
      return {
        ok: false,
        error: `unknown version: ${args.versionParam}`,
        status: 404,
      };
    }
    return { ok: true, value: args.versionParam };
  }

  if (args.pathRef) {
    const fromChannel = resolveChannel(recipe, args.pathRef);
    if (fromChannel) return { ok: true, value: fromChannel };
    if (recipe.versions[args.pathRef]) {
      return { ok: true, value: args.pathRef };
    }
    return {
      ok: false,
      error: `unknown channel or version: ${args.pathRef}`,
      status: 404,
    };
  }

  const channel = args.channelParam ?? "rc";
  const pinned = resolveChannel(recipe, channel);
  if (!pinned) {
    return {
      ok: false,
      error: `unknown or unset channel: ${channel}`,
      status: 404,
    };
  }
  return { ok: true, value: pinned };
}

function shellSingleQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

/** Emit a bash path that expands $HOME at runtime (do not single-quote $HOME). */
function shellHomeAwarePath(path: string): string {
  if (path.startsWith("$HOME")) {
    const rest = path
      .slice("$HOME".length)
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"');
    return `"\${HOME}${rest}"`;
  }
  return shellSingleQuote(path);
}

function buildInstaller(args: {
  recipeId: string;
  version: string;
  url: string;
  sha256: string;
  artifact: string;
  installRoot: string;
}): string {
  const dest = `${args.installRoot}/${args.recipeId}`;
  return `#!/usr/bin/env bash
# mycmd bootstrap — generated by get.mycmd.site
# recipe=${args.recipeId} version=${args.version}
set -euo pipefail

RECIPE_ID=${shellSingleQuote(args.recipeId)}
VERSION=${shellSingleQuote(args.version)}
ARTIFACT_URL=${shellSingleQuote(args.url)}
ARTIFACT_SHA256=${shellSingleQuote(args.sha256)}
ARTIFACT_NAME=${shellSingleQuote(args.artifact)}
DEST=${shellHomeAwarePath(dest)}

echo "mycmd: installing $RECIPE_ID@$VERSION"

export PATH="\${HOME}/.local/bin:\${HOME}/.mise/bin:\${PATH}"

if ! command -v curl >/dev/null 2>&1; then
  echo "mycmd: curl is required" >&2
  exit 1
fi
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  echo "mycmd: sha256sum or shasum is required" >&2
  exit 1
fi

ensure_mise() {
  if command -v mise >/dev/null 2>&1; then
    return 0
  fi
  echo "mycmd: mise not found — attempting install via https://mise.run"
  if curl -fsSL https://mise.run | sh; then
    export PATH="\${HOME}/.local/bin:\${HOME}/.mise/bin:\${PATH}"
  fi
  if command -v mise >/dev/null 2>&1; then
    echo "mycmd: mise ready → \$(command -v mise)"
    return 0
  fi
  echo "mycmd: could not auto-install mise (network/policy/offline?)." >&2
  echo "mycmd: install manually, then re-run this bootstrap:" >&2
  echo "  curl -fsSL https://mise.run | sh" >&2
  echo '  export PATH="$HOME/.local/bin:$PATH"' >&2
  exit 1
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$TMP/$ARTIFACT_NAME"

echo "mycmd: downloading $ARTIFACT_URL"
curl -fsSL "$ARTIFACT_URL" -o "$ARCHIVE"

echo "mycmd: verifying sha256"
if command -v sha256sum >/dev/null 2>&1; then
  printf '%s  %s\\n' "$ARTIFACT_SHA256" "$ARCHIVE" | sha256sum -c -
else
  ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
  if [[ "$ACTUAL" != "$ARTIFACT_SHA256" ]]; then
    echo "mycmd: sha256 mismatch" >&2
    exit 1
  fi
fi

mkdir -p "$DEST"
tar -xzf "$ARCHIVE" -C "$DEST" --strip-components=1
cd "$DEST"

# Extract-only recipes (e.g. workstation patching): no mise / just bootstrap.
if [[ -f .mycmd-extract-only ]]; then
  echo "mycmd: extract-only recipe — skipping mise"
  if [[ -f scripts/check.sh ]]; then
    bash scripts/check.sh
  fi
  echo "mycmd: done → $DEST"
  echo "mycmd: next: see README.md (OS entrypoint; just optional if already installed)"
  exit 0
fi

# Prefer recipe-local guard when present (same UX offline of bootstrap).
if [[ -f scripts/ensure_mise.sh ]]; then
  bash scripts/ensure_mise.sh
else
  ensure_mise
fi

echo "mycmd: mise install (operator tools only — not CUDA/vLLM/weights)"
mise install

if command -v just >/dev/null 2>&1 || mise which just >/dev/null 2>&1; then
  echo "mycmd: just check"
  mise exec -- just check
else
  echo "mycmd: just not available after mise install" >&2
  exit 1
fi

echo "mycmd: done → $DEST"
echo "mycmd: next: cd $DEST && just --list"
`;
}
