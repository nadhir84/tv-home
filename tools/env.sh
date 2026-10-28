# Sourced by the scripts: finds the venv Python, JDK 17 and Android SDK on macOS or Windows (Git Bash).
# Override any of them with PY, JAVA_HOME or ANDROID_HOME.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    WIN=1
    PY="${PY:-$ROOT/tools/venv/Scripts/python.exe}"
    LAD="$(cygpath -u "$LOCALAPPDATA")"
    : "${JAVA_HOME:=$(ls -d "$LAD"/Programs/Microsoft/jdk-17* /c/Program\ Files/Microsoft/jdk-17* 2>/dev/null | head -1)}"
    : "${ANDROID_HOME:=$LAD/Android/Sdk}"
    EXE=.exe BAT=.bat ;;
  *)
    WIN=
    PY="${PY:-$ROOT/tools/venv/bin/python}"
    : "${JAVA_HOME:=/opt/homebrew/opt/openjdk@17}"
    : "${ANDROID_HOME:=/opt/homebrew/share/android-commandlinetools}"
    EXE= BAT= ;;
esac
export JAVA_HOME ANDROID_HOME
export PATH="$JAVA_HOME/bin:$PATH"
