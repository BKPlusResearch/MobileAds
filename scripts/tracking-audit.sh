#!/bin/bash
# tracking-audit.sh <repo-path> <app-code>
#
# Release-time audit of Firebase event names (see docs/tracking-standard.md,
# sections 1, 2, 10, 11). Works on macOS stock bash 3.2 and BSD grep/sed/awk.
#
# Sources of names:
#   1. String literals in *.swift: "<ios|app>NNN_..." or any literal starting
#      with <app-code>. The whole literal content is the name. Skipped dirs:
#      Pods, build, DerivedData, .build.
#   2. Backticked names (pattern [a-z]+NNN_...) in ANY column of markdown table
#      rows (several per cell allowed) in <repo>/docs/event-tracking.md and
#      <repo>/docs/tracking-plan.md. Placeholders containing { } or | are skipped.
#
# Errors (one line each, "ERROR <file>:<line> <name> — <reason>"):
#   - prefix (text before the first "_") differs from <app-code>
#   - characters outside [a-z0-9_]
#   - length > 40
#   - ends with _tap, _open, _impression or _dismiss
#   - Swift line matching: source[^=:]*[:=][^,)]*("unknown"|.unknown)
#     i.e. "source" followed by ':' or '=' and then the literal "unknown" or
#     .unknown before the next ',' or ')' (named argument or assignment).
# Warnings: literals with \( interpolation (composed at runtime, not checked),
#   and more than 300 unique names.
#
# Exit: 0 clean, 1 errors found, 2 bad usage.

usage() {
  echo "usage: $(basename "$0") <repo-path> <app-code>" >&2
  echo "  e.g. $(basename "$0") ~/work_space/BKPlus/ios002-santa-call-message ios002" >&2
}

if [ $# -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  usage
  exit 2
fi
REPO=$1
CODE=$2
if [ ! -d "$REPO" ]; then
  echo "error: repo path is not a directory: $REPO" >&2
  usage
  exit 2
fi
case "$CODE" in
  *[!a-z0-9]*) echo "error: app-code must match [a-z0-9]+: $CODE" >&2; usage; exit 2 ;;
esac

TAB=$(printf '\t')
TMP=$(mktemp -d "${TMPDIR:-/tmp}/tracking-audit.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT
RECORDS="$TMP/records"
: > "$RECORDS"

cd "$REPO" || exit 2

EXCLUDES="--exclude-dir=Pods --exclude-dir=build --exclude-dir=DerivedData --exclude-dir=.build"

# grep "file:line:text" -> "<type>TAB<file>TAB<line>TAB<text>"
to_records() {
  sed -E "s/^(\\.\\/)?(.*):([0-9]+):(.*)\$/$1${TAB}\\2${TAB}\\3${TAB}\\4/"
}

# 1. Swift string literals that look like event names. grep exits 1 on no match.
# shellcheck disable=SC2086
grep -rnoE $EXCLUDES --include='*.swift' \
  "\"((ios|app)[0-9]{3}_|$CODE)[^\"]*\"" . 2>/dev/null | to_records L >> "$RECORDS"

# Swift lines that pass or assign "unknown" as a source.
# shellcheck disable=SC2086
grep -rnE $EXCLUDES --include='*.swift' \
  'source[^=:]*[:=][^,)]*("unknown"|\.unknown([^A-Za-z0-9_]|$))' . 2>/dev/null | to_records S >> "$RECORDS"

# 2. Tracking plan: backticked names in any column of table rows.
for plan in docs/event-tracking.md docs/tracking-plan.md; do
  [ -f "$plan" ] || continue
  awk -F'|' -v f="$plan" '
    /^[ \t]*\|/ {
      for (i = 2; i <= NF; i++) {
        cell = $i
        while (match(cell, /`[a-z]+[0-9][0-9][0-9]_[^`]*`/)) {
          tok = substr(cell, RSTART + 1, RLENGTH - 2)
          cell = substr(cell, RSTART + RLENGTH)
          if (tok ~ /[{}|]/) continue
          printf "P\t%s\t%d\t%s\n", f, NR, tok
        }
      }
    }' "$plan" >> "$RECORDS"
done

awk -F'\t' -v code="$CODE" '
  function err(file, line, name, reason) {
    printf "ERROR %s:%s %s — %s\n", file, line, name, reason
    errors++
  }
  function warn_line(msg) { warns[++nw] = msg }
  {
    type = $1; file = $2; line = $3; val = $4
    if (type == "S") { err(file, line, "source", "\"unknown\" passed as source"); next }
    name = val
    if (type == "L") name = substr(val, 2, length(val) - 2)
    if (index(name, "\\(") > 0) {
      warn_line("WARNING " file ":" line " " name " — runtime-composed name, not checked")
      next
    }
    if (!(name in seen)) { seen[name] = 1; events++ }
    p = index(name, "_")
    prefix = (p > 0) ? substr(name, 1, p - 1) : name
    if (prefix != code) err(file, line, name, "prefix \"" prefix "\" is not \"" code "\"")
    if (name !~ /^[a-z0-9_]+$/) err(file, line, name, "characters outside [a-z0-9_]")
    if (length(name) > 40) err(file, line, name, "length " length(name) " exceeds 40")
    if (name ~ /_(tap|open|impression|dismiss)$/) err(file, line, name, "forbidden action suffix")
  }
  END {
    if (events > 300) warn_line("WARNING " events " unique event names exceed 300")
    for (i = 1; i <= nw; i++) print warns[i]
    printf "SUMMARY events=%d errors=%d warnings=%d\n", events, errors, nw
    exit (errors > 0) ? 1 : 0
  }' "$RECORDS"
