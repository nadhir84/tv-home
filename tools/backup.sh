#!/usr/bin/env bash
# Snapshot the TV's package state before changing anything: enabled, disabled and third-party
# packages, the current home activity and device props. Saved to backup/<timestamp>/ (git-ignored).
# To get back to exactly this state, re-enable anything that was in enabled.txt:
#   tools/restore.sh backup/<timestamp>/enabled.txt
# Usage: tools/backup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/env.sh
DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DIR"
tv() { "$PY" -I tools/tv.py "$@"; }

tv 'pm list packages -e' | sed -n 's/^package://p' | tr -d '\r' | sort > "$DIR/enabled.txt"
tv 'pm list packages -d' | sed -n 's/^package://p' | tr -d '\r' | sort > "$DIR/disabled.txt"
tv 'pm list packages -3 -i' | tr -d '\r' | sort > "$DIR/third-party.txt"
tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' \
  | tr -d '\r' > "$DIR/home-activity.txt"
tv --probe | tr -d '\r' > "$DIR/device.txt"
echo "Backed up to $DIR: $(wc -l < "$DIR/enabled.txt") enabled, $(wc -l < "$DIR/disabled.txt") disabled packages"
