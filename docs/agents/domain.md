# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root (glossary + distribution architecture).
- **`docs/adr/`**: ADRs authored via `/to-adr`. Filenames: `<project-key>-NNNN-ADR-<slug>.md`. Indexed by [`docs/adr/index.md`](../adr/index.md).
- **`docs/prd/`**: PRDs (gitignored; setup **A**) — author via `/to-prd`; not committed.
- **`knowledge/`**: OKF progressive disclosure; start at [`knowledge/index.md`](../../knowledge/index.md).

If any of these files don't exist, **proceed silently**. Don't flag their absence. Use `/to-adr` when decisions need recording. `/domain-modeling` / `context` may still create/update `CONTEXT.md` lazily when terms get resolved.

## File structure

Single-context repo:

```
/
├── CONTEXT.md
├── knowledge/           ← OKF concepts (index.md)
├── docs/
│   ├── agents/          ← skill config (issue tracker, triage, domain rules)
│   ├── adr/             ← /to-adr home (bmurrtech)
│   └── prd/             ← /to-prd home (ignored; setup A)
├── scripts/
│   ├── local-ai/        ← packageable Qwen recipes (spark + rtx-6000-pro)
│   └── security/        ← packageable vps-baseline
├── bootstrap/           ← Cloudflare Worker (get.mycmd.site)
├── catalog/             ← recipe → channel → version → artifact map
└── …
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `context` / domain modeling).

## Flag ADR conflicts

If your output contradicts an existing ADR under `docs/adr/`, surface it explicitly rather than silently overriding:

> _Contradicts how-to-selfhost-0001-ADR-…, but worth reopening because…_
