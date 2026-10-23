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
scripts/release.sh X.Y.Z    # Developer ID signing + notarization (notarytool profile "Subus"), appcast.xml
git push origin main vX.Y.Z
git switch develop && git merge --ff-only main && git push origin develop
gh release create vX.Y.Z dist/Subus-X.Y.Z.dmg dist/Subus.dmg dist/appcast.xml --title "Subus X.Y.Z" --notes-file <notes>
```

The release always carries three files: `Subus-X.Y.Z.dmg`, `Subus.dmg` (the README's download link) and `appcast.xml`. Installed copies find the update through `releases/latest/download/appcast.xml` as soon as the release is published, so publish it only with all three attached. Sparkle compares `CFBundleVersion`, the commit count, which is why a release is built from `main`.

### Update signing key (once)

`scripts/build-app.sh` resolves Sparkle into `build/DerivedData`; its tools are in `build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`.

- `generate_keys --account io.github.aesarva.Subus` creates the EdDSA key in the login keychain; its public half is `SUPublicEDKey` in `App/Resources/Info.plist`. `sign_update --account io.github.aesarva.Subus` (run by `scripts/make-appcast.sh`) signs the DMG with it.
- Back it up with `generate_keys --account io.github.aesarva.Subus -x <file>` and keep the file off this Mac. Losing it leaves only a key rotation through a release signed with the same Developer ID; losing both, installed copies accept no update again.

### Testing an update end to end

- `-UpdateFeedURL <url>` checks a different appcast, for example one served from `http://127.0.0.1:8000`; `FEED_BASE=http://127.0.0.1:8000 scripts/make-appcast.sh <dmg> <version> <build>` writes one that points at the local DMG.
- `-UpdateAutoInstall YES` installs a found update without the click.
- `BUILD_NUMBER=<n> scripts/release.sh <version>` builds an older copy to update from. Both copies must be signed with the Developer ID and notarized, and the older one must sit in `/Applications`.

## Before merging

- `make test` passes.
- `make build` succeeds without new warnings.
- Every new user-visible string has a Russian translation in `App/Resources/Localizable.xcstrings`.
- UI changes follow [DESIGN.md](DESIGN.md).
- UI changes: `make snapshots` runs cleanly and the affected states look right in light and dark, English and Russian.
