#!/usr/bin/env bash
# Build the launcher APK with the bare SDK tools (no Gradle) and install it on the TV as the home screen.
#   launcher/build-and-install.sh            build + install
#   launcher/build-and-install.sh --build    build only
set -euo pipefail
cd "$(dirname "$0")"
. ../tools/env.sh
SDK="$ANDROID_HOME"
BT="$SDK/build-tools/34.0.0"
JAR="$SDK/platforms/android-34/android.jar"
# Google TV stock launcher; older Android TV sets use com.google.android.tvlauncher.
STOCK_LAUNCHER="${STOCK_LAUNCHER:-com.google.android.apps.tv.launcherx}"
B=build

rm -rf "$B" && mkdir -p "$B/gen" "$B/classes" "$B/dex"
"$BT/aapt2$EXE" compile --dir res -o "$B/res.zip"
"$BT/aapt2$EXE" link -o "$B/base.apk" -I "$JAR" --manifest AndroidManifest.xml --java "$B/gen" \
  -A assets --min-sdk-version 30 --target-sdk-version 30 "$B/res.zip"
javac -encoding UTF-8 -nowarn -Xlint:-options --release 11 -classpath "$JAR" -d "$B/classes" \
  $(find src "$B/gen" -name '*.java')
"$BT/d8$BAT" --min-api 30 --lib "$JAR" --output "$B/dex" $(find "$B/classes" -name '*.class')
if command -v zip >/dev/null; then cp "$B/base.apk" "$B/unsigned.apk"; (cd "$B/dex" && zip -q -u ../unsigned.apk classes.dex)
else  # Git Bash on Windows has no zip: rewrite the APK (appending in place breaks its local headers)
  "$PY" -I -c '
import sys, zipfile
src, dex, out = sys.argv[1:]
with zipfile.ZipFile(src) as a, zipfile.ZipFile(out, "w") as b:
    for i in a.infolist():
        b.writestr(i.filename, a.read(i), compress_type=i.compress_type)
    b.write(dex, "classes.dex", compress_type=zipfile.ZIP_DEFLATED)
' "$B/base.apk" "$B/dex/classes.dex" "$B/unsigned.apk"
fi
"$BT/zipalign$EXE" -f 4 "$B/unsigned.apk" "$B/aligned.apk"
[ -f debug.keystore ] || keytool -genkeypair -keystore debug.keystore -storepass android -keypass android \
  -alias tvhome -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=tvhome" >/dev/null 2>&1
"$BT/apksigner$BAT" sign --ks debug.keystore --ks-pass pass:android --out "$B/tvhome.apk" "$B/aligned.apk"
echo "built $B/tvhome.apk ($(wc -c < "$B/tvhome.apk") bytes)"
[ "${1:-}" = "--build" ] && exit 0

# MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the TV-side path into a Windows one
MSYS_NO_PATHCONV=1 "$PY" -I ../tools/tv.py --push-b64 "$B/tvhome.apk" /data/local/tmp/tvhome.apk
printf '%s\n' \
  "pm install -r /data/local/tmp/tvhome.apk" \
  "rm -f /data/local/tmp/tvhome.apk" \
  "pm grant com.mihir.tvhome android.permission.ACCESS_FINE_LOCATION" \
  "cmd package set-home-activity --user 0 com.mihir.tvhome/.MainActivity" \
  "pm disable-user --user 0 $STOCK_LAUNCHER" \
  "pm disable-user --user 0 com.google.android.tungsten.setupwraith" \
  "cmd package set-home-activity --user 0 com.mihir.tvhome/.MainActivity" \
  "am force-stop com.android.tv.settings" \
  "input keyevent KEYCODE_HOME" \
  | "$PY" -I ../tools/tv.py --batch
echo "Installed. Press Home on the remote."
