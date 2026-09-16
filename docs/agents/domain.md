# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root (glossary + distribution architecture).
- **`docs/ADRs/`**: ADRs authored via `/to-adr` (`.cursor/to-adr/SKILL.md`). Filenames: `<project-key>-NNNN-ADR-<slug>.md`. **Not** Matt's `docs/adr/`.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating Matt-style `docs/adr/` trees. Use `/to-adr` (and `/setup-pf` if ADR home is missing) when decisions need recording. `/domain-modeling` may still create/update `CONTEXT.md` lazily when terms get resolved.

## File structure

Single-context repo:

```
/
├── CONTEXT.md
├── docs/
│   ├── agents/          ← skill config (issue tracker, triage, domain rules)
│   └── ADRs/            ← /to-adr home (not docs/adr/)
├── scripts/
│   ├── local-ai/        ← packageable Qwen recipes (spark + rtx-6000-pro)
│   └── security/        ← packageable vps-baseline
├── bootstrap/           ← Cloudflare Worker (get.mycmd.site)
├── catalog/             ← recipe → channel → version → artifact map
└── …
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR under `docs/ADRs/`, surface it explicitly rather than silently overriding:

> _Contradicts how-to-selfhost-0001-ADR-…, but worth reopening because…_
