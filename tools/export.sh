#!/usr/bin/env bash
# Exports Windows and Android from a frozen copy of the project (spec section 9).
# Usage: tools/export.sh
# Environment:
#   GODOT         the console build of Godot (default: /mnt/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe)
#   ANDROID_SDK   the Android SDK folder (default: export/android/android_sdk_path of the editor settings)
#   KEEP_SNAPSHOT set to 1 to keep the snapshot after the run
#   STEP_TIMEOUT  the time limit of each Godot step, in seconds (default: 1800; the level check takes minutes)
set -euo pipefail

godot=${GODOT:-/mnt/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}
root=$(cd "$(dirname "$0")/.." && pwd)
stamp=$(date +%Y%m%d-%H%M%S)
snap_dir=$root/build/snapshot/$stamp
snap=$snap_dir/proj
log=$root/build/export.log
win_out=$root/build/windows/trilha-jujuba.exe
apk_out=$root/build/android/trilha-jujuba-debug.apk
editor_version=4.7

fail() {
	echo "ERR $*" | tee -a "$log" >&2
	exit 1
}

cleanup() {
	if [[ -d $snap_dir && ${KEEP_SNAPSHOT:-0} != 1 ]]; then
		rm -rf "$snap_dir"
		rmdir "$root/build/snapshot" 2>/dev/null || true
	fi
}
trap cleanup EXIT

[[ -x $godot ]] || { echo "ERR Godot not found at $godot (set GODOT)" >&2; exit 1; }
mkdir -p "$root/build"
: > "$log"

# Runs one Godot command (an array), logs it, and stops on a non-zero exit code or a line that matches $2.
run_godot() {
	local label=$1 pattern=$2
	shift 2
	local cmd=("$@")
	printf '\n== %s\n' "$label" | tee -a "$log"
	local mark code=0
	mark=$(wc -l < "$log")
	timeout "${STEP_TIMEOUT:-1800}" "${cmd[@]}" 2>&1 | tr -d '\r' | tee -a "$log" || code=$?
	[[ $code -eq 0 ]] || fail "step '$label' failed with exit code $code (log: build/export.log)"
	if tail -n +"$((mark + 1))" "$log" | grep -qE "$pattern"; then
		fail "step '$label' printed an error line (log: build/export.log)"
	fi
}

live_win=$(wslpath -w "$root")

# 1. Checks on the live project.
level_check=("$godot" --headless --path "$live_win" --script res://tools/levels_tool.gd -- --check)
run_godot "1/7 level check" 'ERROR:|SCRIPT ERROR' "${level_check[@]}"
load_check=("$godot" --headless --path "$live_win" --script res://tools/load_all.gd)
run_godot "1/7 load check" 'ERROR:|SCRIPT ERROR' "${load_check[@]}"
grep -q '^LOAD_OK ' "$log" || fail "load_all.gd did not print LOAD_OK"

# 2. Frozen copy, with the .godot folder.
printf '\n== 2/7 snapshot %s\n' "${snap#$root/}" | tee -a "$log"
mkdir -p "$snap"
rsync -a --exclude '/build/' --exclude '/shots/' --exclude '/images-codex/' --exclude '/.git/' "$root/" "$snap/"
snap_win=$(wslpath -w "$snap")

# 3. Import on the snapshot.
import_cmd=("$godot" --headless --path "$snap_win" --import)
run_godot "3/7 import" 'ERROR:|SCRIPT ERROR' "${import_cmd[@]}"

# 4. Boot check on the snapshot. The save goes to the snapshot, not to the save of the user.
boot_save_win=$(wslpath -w "$snap_dir")\\boot_save.cfg
boot_cmd=("$godot" --headless --path "$snap_win" -- --level=1 --solve --quit-at=result --timeout=60 "--save=$boot_save_win")
run_godot "4/7 boot check" 'ERROR:|SCRIPT ERROR|WARNING:' "${boot_cmd[@]}"
grep -q 'HARNESS MARK result' "$log" || fail "the boot check did not reach the result card"

# 5. Exports from the snapshot.
mkdir -p "$(dirname "$win_out")" "$(dirname "$apk_out")"
rm -f "$win_out" "$apk_out"
win_out_win=$(wslpath -w "$(dirname "$win_out")")\\$(basename "$win_out")
apk_out_win=$(wslpath -w "$(dirname "$apk_out")")\\$(basename "$apk_out")
windows_cmd=("$godot" --headless --path "$snap_win" --export-release "Windows Desktop" "$win_out_win")
run_godot "5/7 export Windows" 'ERROR:' "${windows_cmd[@]}"
android_cmd=("$godot" --headless --path "$snap_win" --export-debug "Android" "$apk_out_win")
run_godot "5/7 export Android" 'ERROR:' "${android_cmd[@]}"

# 6. Outputs and the APK signature.
printf '\n== 6/7 outputs\n' | tee -a "$log"
for out in "$win_out" "$apk_out"; do
	[[ -s $out ]] || fail "the export finished but ${out#$root/} is missing or empty"
	echo "SIZE ${out#$root/} $(du -h "$out" | cut -f1)" | tee -a "$log"
done

appdata=$(wslpath "$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')")
editor_settings=$appdata/Godot/editor_settings-$editor_version.tres
setting() {
	sed -n "s|^$1 = \"\\(.*\\)\"\$|\\1|p" "$editor_settings" 2>/dev/null | head -n 1
}
sdk=${ANDROID_SDK:-$(setting export/android/android_sdk_path)}
[[ -n $sdk ]] || fail "no Android SDK: set ANDROID_SDK or export/android/android_sdk_path"
[[ $sdk == /* ]] || sdk=$(wslpath "$sdk")
build_tools=$(ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -n 1)
apksigner=${build_tools%/}/apksigner.bat
[[ -f $apksigner ]] || fail "apksigner.bat not found under $sdk/build-tools"
java_home=$(setting export/android/java_sdk_path)
verify_cmd=(cmd.exe /c "$(wslpath -w "$apksigner")" verify --print-certs "$apk_out_win")
printf '\n== 6/7 apksigner verify\n' | tee -a "$log"
code=0
JAVA_HOME=${java_home//\//\\} WSLENV=${WSLENV:+$WSLENV:}JAVA_HOME "${verify_cmd[@]}" 2>&1 | tr -d '\r' | tee -a "$log" || code=$?
[[ $code -eq 0 ]] || fail "apksigner verify failed with exit code $code"

# 7. The trap deletes the snapshot.
printf '\n== 7/7 done\n' | tee -a "$log"
echo "RESULT ok: build/windows/trilha-jujuba.exe and build/android/trilha-jujuba-debug.apk (log: build/export.log)" | tee -a "$log"
