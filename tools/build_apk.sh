#!/usr/bin/env bash
# Exports the debug APK and installs it on the one connected phone.
# Usage: tools/build_apk.sh [--no-install]
# Overrides: GODOT, ADB, ANDROID_SERIAL.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

install=1
for arg in "$@"; do
	case "$arg" in
		--no-install) install=0 ;;
		*) echo "unknown argument: $arg (only --no-install is supported)" >&2; exit 2 ;;
	esac
done

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "godot not found: install it (docs/dev-setup.md step A) or set GODOT" >&2
	exit 1
fi

version="$("$GODOT" --version | cut -d. -f1-4)"
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
if [ ! -f "$templates/android_debug.apk" ]; then
	echo "Android export templates missing: expected $templates/android_debug.apk (docs/dev-setup.md step E)" >&2
	exit 1
fi

apk="build/pieceful-debug.apk"
mkdir -p build
rm -f "$apk"
"$GODOT" --headless --import
"$GODOT" --headless --export-debug "Android" build/pieceful-debug.apk
if [ ! -f "$apk" ]; then
	echo "export produced no $apk: open Project, Export, Android in the editor and read what it reports" >&2
	exit 1
fi

if [ "$install" -eq 0 ]; then
	echo "built $PWD/$apk"
	exit 0
fi

adb=""
for candidate in "${ADB:-}" \
	"${ANDROID_HOME:+$ANDROID_HOME/platform-tools/adb}" \
	"${ANDROID_SDK_ROOT:+$ANDROID_SDK_ROOT/platform-tools/adb}" \
	"$HOME/Android/Sdk/platform-tools/adb"; do
	if [ -n "$candidate" ] && [ -x "$candidate" ]; then
		adb="$candidate"
		break
	fi
done
if [ -z "$adb" ] && command -v adb >/dev/null 2>&1; then
	adb="adb"
fi
if [ -z "$adb" ]; then
	echo "adb not found (looked at \$ADB, \$ANDROID_HOME, \$ANDROID_SDK_ROOT, ~/Android/Sdk/platform-tools and PATH): nothing was installed"
	echo "built $PWD/$apk"
	exit 0
fi

devices="$("$adb" devices | tail -n +2)"
ready="$(awk '$2 == "device" {print $1}' <<<"$devices")"
unauthorized="$(awk '$2 == "unauthorized" {print $1}' <<<"$devices")"
count=0
if [ -n "$ready" ]; then
	count="$(wc -l <<<"$ready")"
fi

if [ "$count" -eq 0 ]; then
	echo "no phone is connected: nothing was installed"
	if [ -n "$unauthorized" ]; then
		echo "unauthorized device(s): $(tr '\n' ' ' <<<"$unauthorized")- accept the USB debugging prompt on the phone and run again"
	fi
	echo "built $PWD/$apk"
	exit 0
fi
if [ "$count" -gt 1 ] && [ -z "${ANDROID_SERIAL:-}" ]; then
	echo "more than one device is connected: set ANDROID_SERIAL to one of: $(tr '\n' ' ' <<<"$ready")" >&2
	exit 1
fi

status=0
"$adb" install -r "$apk" || status=$?
if [ "$status" -ne 0 ]; then
	echo "install failed. If adb reported a signature mismatch, run 'adb uninstall io.github.aaryash_shakya.pieceful' first; that deletes the save." >&2
	exit "$status"
fi
echo "installed $PWD/$apk"
