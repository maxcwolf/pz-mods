# 0001: One public repo for all mods

Date: 2026-11-07

## Context

Each mod lived in its own folder, `workspace/pz-<name>`. Each folder had its
own git repo, and only Choose Starting Gear had any commits. Max wanted all of
them published together, credited to his Steam Workshop name, jabroni.

## Decision

All mods live in one public repo, `maxcwolf/pz-mods`. Each mod has its own
folder, with the `pz-` prefix dropped, and keeps its layout unchanged
(`mod/<Id>/42`, `test/`, `scripts/install.sh`, `docs/`). Choose Starting
Gear's history was brought in with a subtree merge, so its earlier commits are
kept. In those older commits its files sit at the repo root. The other eight
had no commits, so each one went in as a single `feat: add ...` commit. Every
mod.info now reads `author=jabroni`.

## Consequences

- One place to clone, test and tag. Releases are tagged per mod as
  `<mod>-v<version>`, because the mods ship to the Workshop separately.
- The `~/Zomboid/mods` symlinks were relinked to the new paths with each
  mod's `install.sh`.
- `git log -- choose-starting-gear` shows only commits from after the merge.
  Use `git log --follow` on a file, or look at the commits before the merge,
  to see the older history.

## How to reverse

To split a mod back out with its history:

```bash
git subtree split --prefix=<mod> -b <mod>-only
```

Then push that branch to a new repo. To go back to the old separate folders,
copy each folder back out to `workspace/pz-<name>` and run its `install.sh`.
