#!/usr/bin/env bash
# release-notes.sh: print the GitHub release title or description for a
# version, taken from RELEASE_NOTES.md. Read-only.
#
# Usage:
#   release-notes.sh [--title | --body] [--repo URL] [--file PATH] VERSION
#
#   VERSION        the version, with or without the v: 0.0.3 or v0.0.3
#   --title        print the release title (default): "v" + the section's
#                  heading without its trailing date, e.g. "v0.0.3: Autopilot"
#   --body         print the release description: the section's text, from
#                  the line after its heading to the line before the next h2
#   --repo URL     with --body, append a "Full Changelog" link comparing the
#                  previous version tag with this one
#   --file PATH    release notes file (default: RELEASE_NOTES.md)
#
# The section for VERSION is the h2 that starts "## VERSION:". The script
# fails if there isn't one.
# Docs: scripts/release-notes.md

set -euo pipefail

mode=title
repo=''
file=RELEASE_NOTES.md
version=''

die() { echo "release-notes: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --title)   mode=title; shift ;;
    --body)    mode=body; shift ;;
    --repo)    (($# >= 2)) || die "--repo needs a URL"; repo=${2%/}; shift 2 ;;
    --file)    (($# >= 2)) || die "--file needs a path"; file=$2; shift 2 ;;
    -h|--help) usage 0 ;;
    -*)        echo "release-notes: unknown option: $1" >&2; usage 1 >&2 ;;
    *)         [[ -z $version ]] || die "only one VERSION, please"; version=$1; shift ;;
  esac
done

[[ -n $version ]] || { echo "release-notes: VERSION is required" >&2; usage 1 >&2; }
version=${version#v}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "not a version: $version"
[[ -f $file ]] || die "no such file: $file"

# The section's heading, e.g. "## 0.0.3: Autopilot (2026-10-15)".
heading=$(grep -m1 -E "^## ${version//./\\.}:" "$file" || true)
[[ -n $heading ]] || die "no '## $version:' section in $file"

if [[ $mode == title ]]; then
  title=${heading#'## '}
  title=$(sed -E 's/[[:space:]]*\([0-9]{4}-[0-9]{2}-[0-9]{2}\)[[:space:]]*$//' <<<"$title")
  echo "v$title"
  exit 0
fi

# The section's text, without leading and trailing blank lines.
awk -v heading="$heading" '
  $0 == heading { inside = 1; next }
  inside && /^## / { exit }
  inside { lines[++n] = $0 }
  END {
    first = 1; while (first <= n && lines[first] ~ /^[[:space:]]*$/) first++
    last = n;  while (last >= first && lines[last] ~ /^[[:space:]]*$/) last--
    for (i = first; i <= last; i++) print lines[i]
  }
' "$file"

if [[ -n $repo ]]; then
  tag=v$version
  # The nearest version tag before this one, in history.
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    previous=$(git describe --tags --abbrev=0 --match 'v[0-9]*' "$tag^" 2>/dev/null || true)
  else
    previous=$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || true)
  fi
  echo
  if [[ -n $previous && $previous != "$tag" ]]; then
    echo "**Full Changelog**: $repo/compare/$previous...$tag"
  else
    echo "**Full Changelog**: $repo/commits/$tag"
  fi
fi
