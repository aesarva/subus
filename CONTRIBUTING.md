# Contributing

## Branches

- **`main`** — released code only. It changes only by merging `develop` for a release.
- **`develop`** — integration branch. Every change lands here first.
- **Work branches** — one per change, created from `develop` and merged back into `develop`:

  | Prefix | For |
  |---|---|
  | `feature/<name>` | new functionality |
  | `fix/<name>` | bug fixes |
  | `docs/<name>` | documentation only |
  | `chore/<name>` | build, tooling, dependencies |

```sh
git switch develop && git pull
git switch -c feature/catalogue
# … commits …
git switch develop && git merge --no-ff feature/catalogue
git branch -d feature/catalogue
```

Merge with `--no-ff` (or a pull request into `develop`) so each change stays visible as one unit in the history. Commits are conventional, in English, lowercase: `feat(panel): …`, `fix: …`.

## Releases

On `develop`, before the merge:

1. Bump `MARKETING_VERSION` in `project.yml` and the `VERSION` default in the `Makefile`.
2. Move the `## Unreleased` entries in `CHANGELOG.md` under `## X.Y.Z — <date>`.
3. Run `make test` and `make snapshots`.

Then:

```sh
git switch main && git merge --no-ff develop
git tag vX.Y.Z
scripts/release.sh X.Y.Z    # Developer ID signing + notarization (notarytool profile "Subus")
```

Attach `dist/Subus-X.Y.Z.dmg` and `dist/Subus.dmg` to the GitHub release.

## Before merging

- `make test` passes.
- `make build` succeeds without new warnings.
- Every new user-visible string has a Russian translation in `App/Resources/Localizable.xcstrings`.
- UI changes follow [DESIGN.md](DESIGN.md).
- UI changes: `make snapshots` runs cleanly and the affected states look right in light and dark, English and Russian.
