# release-notes.sh

Print the GitHub release title or description for a version, taken from
`RELEASE_NOTES.md`.

| | |
|-|-|
| **Script** | [`release-notes.sh`](release-notes.sh) |
| **Changes anything?** | No |
| **Runs on** | Laptop, and the `release` workflow in GitHub Actions |
| **Needs** | bash, GNU awk/sed/grep, git (for `--repo`) |

## Usage

```sh
scripts/release-notes.sh 0.0.3                     # title: v0.0.3: <Title>
scripts/release-notes.sh --body 0.0.3              # description
scripts/release-notes.sh --body --repo https://github.com/bvraghav/homelab v0.0.3
scripts/release-notes.sh --help
```

## Options

`VERSION`
: The version, with or without the `v`: `0.0.3` or `v0.0.3`.

`--title`
: Print the release title (the default): `v` plus the section's heading
  without its trailing date. `## 0.0.3: Autopilot (2026-10-15)` gives
  `v0.0.3: Autopilot`.

`--body`
: Print the release description: the section's text, from the line after
  its heading to the line before the next h2, without leading and trailing
  blank lines.

`--repo URL`
: With `--body`, append `**Full Changelog**: URL/compare/<previous>...vX.Y.Z`.

`--file PATH`
: The release notes file. Default: `RELEASE_NOTES.md`.

## Before you run it

- Run it from the repository root, or pass `--file`.
- `RELEASE_NOTES.md` needs a section for the version, headed
  `## X.Y.Z: Title (YYYY-MM-DD)`.

## How it works

- The section is the first h2 starting with `## X.Y.Z:`. The script fails if
  there's none, so a release can't go out with empty notes.
- The previous version is the nearest `v*` tag in the history before
  `vX.Y.Z` (or before `HEAD`, if the tag doesn't exist yet), not simply
  `X.Y.(Z-1)`. That still works after a minor or major bump. For the first
  release, the link lists the tag's commits instead.

## Safety

- Read-only: it only prints.

## Limitations

- Relative links inside the section, such as `CHANGELOG.md`, aren't
  rewritten, so they won't work in the GitHub release. Use full URLs in
  release notes.

## See also

- `.github/workflows/release.yml`, which uses it to create each release.
- [All scripts](MANIFEST.md)
