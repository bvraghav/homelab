#!/usr/bin/env bash
# scrub-history.sh: find, and optionally remove, shell history entries that
# look like they contain secrets. Values are always masked in the output.
#
# Usage:
#   scrub-history.sh [--file PATH] [--pattern REGEX] [--apply [--force]]
#
#   (default)        list matching entries, masked; change nothing
#   --file PATH      history file (default: ~/.zsh_history if it exists,
#                    otherwise ~/.bash_history)
#   --pattern REGEX  extra case-insensitive ERE, added to the built-in one
#   --apply          back up the file privately, then remove whole matching
#                    entries (multi-line zsh entries included)
#   --force          apply even if other shells of the same kind are running
#
# Before --apply, run `unset HISTFILE` in the shell you run this from, and
# close other terminals; a running shell can write the old history back.
# Walkthrough: docs/blog/tutorials/scrub-history.md

set -euo pipefail

PATTERN='from-literal|password|passwd|secret|token|api[-_]?key|client[-_]?secret|AGE-SECRET-KEY|PRIVATE KEY|argon2'

file=''
extra=''
apply=false
force=false

die() { echo "scrub-history: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --file)    (($# >= 2)) || die "--file needs a path"; file=$2; shift 2 ;;
    --pattern) (($# >= 2)) || die "--pattern needs a regex"; extra=$2; shift 2 ;;
    --apply)   apply=true; shift ;;
    --force)   force=true; shift ;;
    -h|--help) usage 0 ;;
    *)         echo "scrub-history: unknown argument: $1" >&2; usage 1 >&2 ;;
  esac
done

if [[ -z $file ]]; then
  if [[ -f $HOME/.zsh_history ]]; then file=$HOME/.zsh_history
  else file=$HOME/.bash_history; fi
fi
[[ -f $file ]] || die "no such file: $file"
[[ -n $extra ]] && PATTERN="$PATTERN|$extra"

# Which shell writes this file: zsh files use backslash continuations for
# multi-line entries; bash files are one command per line.
case $(basename "$file") in
  *zsh*) shell=zsh ;;
  *)     shell=bash ;;
esac

# Group lines into entries (joining zsh continuation lines) and either list
# the matching ones or print the ones to keep. LC_ALL=C because zsh stores
# non-ASCII characters in its own encoding.
entries() {  # $1 = list | keep
  LC_ALL=C awk -v pat="$PATTERN" -v mode="$1" -v zsh="$([[ $shell == zsh ]] && echo 1 || echo 0)" '
    function flush() {
      if (entry == "") return
      hit = (tolower(entry) ~ tolower(pat))
      if (mode == "list" && hit) { gsub(/\\\n */, " ↵ ", entry); printf "%d\t%s\n", start, entry }
      if (mode == "keep" && !hit) printf "%s\n", entry
      entry = ""
    }
    {
      if (entry == "") { start = NR; entry = $0 } else entry = entry "\n" $0
      if (zsh && /\\$/) next
      flush()
    }
    END { flush() }
  ' "$file"
}

mask() {
  sed -E "s/=[^ ]+/=****/g; s/'[^']*'/'****'/g; s/\"[^\"]*\"/\"****\"/g" | cut -c1-140
}

matches=$(entries list | mask)
count=$(grep -c . <<<"$matches" || true)

echo "file:    $file ($shell format)"
echo "matches: $count entries"
if ((count > 0)); then
  echo
  printf '%s\n' "$matches" | sed 's/^/  line /'
  echo
fi

if ! $apply; then
  ((count > 0)) && echo "Nothing changed. Re-run with --apply to remove these entries."
  exit 0
fi

((count > 0)) || { echo "Nothing to remove."; exit 0; }

# Other running shells of the same kind may write their in-memory history
# back over the cleaned file. The shell running this script counts as one.
others=$(pgrep -u "$UID" -x "$shell" | wc -l)
if ((others > 1)) && ! $force; then
  die "$others $shell processes are running. Close the other terminals (and
run 'unset HISTFILE' in this one), or pass --force if you're sure."
fi

umask 077
backup="$file.bak.$(date +%Y%m%d-%H%M%S)"
cp -p "$file" "$backup"

tmp=$(mktemp "$file.XXXXXX")
trap 'rm -f "$tmp"' EXIT
entries keep > "$tmp"
chmod --reference="$file" "$tmp" 2>/dev/null || chmod 600 "$tmp"
mv "$tmp" "$file"
trap - EXIT

left=$(entries list | grep -c . || true)
echo "Removed $count entries; $left matching entries left."
echo "Backup (contains the secrets): $backup"
echo
echo "Next: open a new terminal and check its history works, then delete the"
echo "backup (shred -u \"$backup\") and rotate anything that was exposed."
