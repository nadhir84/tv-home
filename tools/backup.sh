#!/usr/bin/env bash
# Snapshot the TV before changing anything: device info, enabled/disabled packages, the current home
# activity, key settings and a screenshot. Writes backup/<timestamp>/ with a restore.sh that puts the
# TV back exactly as it was in this snapshot (independent of any debloat list).
# Usage: tools/backup.sh            then later: backup/<timestamp>/restore.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${PY:-tools/venv/bin/python}"
DIR="backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DIR"
tv() { "$PY" -I tools/tv.py "$@"; }

tv --probe > "$DIR/device.txt"
tv 'pm list packages -e' | tr -d '\r' | sed -n 's/^package://p' | LC_ALL=C sort > "$DIR/enabled.txt"
tv 'pm list packages -d' | tr -d '\r' | sed -n 's/^package://p' | LC_ALL=C sort > "$DIR/disabled.txt"
tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' \
  | tail -1 | tr -d '\r' > "$DIR/home.txt"
for k in "global package_verifier_user_consent" "secure screensaver_components" "secure default_input_method"; do
  echo "$k = $(tv "settings get $k" | tr -d '\r')"
done > "$DIR/settings.txt"
tv --shot "$DIR/before.png" >/dev/null

HOME_ACT=$(cat "$DIR/home.txt")
case "$HOME_ACT" in */*) ;; *) echo "Couldn't read the home activity (got '$HOME_ACT')"; exit 1 ;; esac

cat > "$DIR/restore.sh" <<EOF
#!/usr/bin/env bash
# Restore the TV to the snapshot taken on $(date '+%Y-%m-%d %H:%M').
# Re-enables every package that was enabled then and is disabled now, and makes
# $HOME_ACT the home screen again. The tv-home launcher stays installed but unused.
set -euo pipefail
SNAP="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SNAP/../.."
PY="\${PY:-tools/venv/bin/python}"
now=\$(mktemp)
"\$PY" -I tools/tv.py 'pm list packages -d' | tr -d '\r' | sed -n 's/^package://p' | LC_ALL=C sort > "\$now"
{
  LC_ALL=C comm -12 "\$SNAP/enabled.txt" "\$now" | awk '{print "pm enable " \$1}'
  echo "cmd package set-home-activity --user 0 $HOME_ACT"
  echo "am force-stop com.mihir.tvhome"
  echo "input keyevent KEYCODE_HOME"
} | "\$PY" -I tools/tv.py --batch
rm -f "\$now"
"\$PY" -I tools/tv.py --shot "\$SNAP/after-restore.png" >/dev/null
echo "Restored. Compare \$SNAP/before.png with \$SNAP/after-restore.png."
EOF
chmod +x "$DIR/restore.sh"

echo "Backup in $DIR: $(wc -l < "$DIR/enabled.txt") enabled, $(wc -l < "$DIR/disabled.txt") disabled packages, home = $HOME_ACT"
echo "Undo everything later with: $DIR/restore.sh"
