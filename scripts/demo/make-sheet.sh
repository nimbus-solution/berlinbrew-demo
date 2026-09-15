#!/bin/zsh
# make-sheet.sh — writes the demo spreadsheet with the record Ids this machine
# actually has. Run seed-demo-accounts.apex first.
#
#   ./scripts/demo/make-sheet.sh
#
# nimbus renders a debug line quoted, so the CSV| payload is unquoted here
# before it is written out.
set -eu
cd "$(dirname "$0")/../.."
OUT=scripts/demo/lifetime-value-corrections.csv
nimbus exec scripts/demo/build-sheet.apex 2>/dev/null \
  | sed -n 's/.*CSV|//p' \
  | sed 's/"$//' \
  > "$OUT"
lines=$(wc -l < "$OUT" | tr -d ' ')
if [ "$lines" -lt 2 ]; then
  echo "no rows — run 'nimbus exec scripts/demo/seed-demo-accounts.apex' first" >&2
  exit 1
fi
echo "wrote $OUT ($((lines - 1)) rows)"
cat "$OUT"
