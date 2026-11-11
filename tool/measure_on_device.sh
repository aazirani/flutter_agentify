#!/usr/bin/env bash
# Measures the model inside the app on one device and prints one Markdown
# table row: ten fixed requests against the app's actions, how many were
# right, how fast the first token came, and the peak memory. The first run
# downloads the model (about 2.6 GB).
# Usage: tool/measure_on_device.sh -d <device id> [--cpu]
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { echo "Usage: tool/measure_on_device.sh -d <device id> [--cpu]" >&2; exit 64; }
device=""
backend=gpu
while [ $# -gt 0 ]; do
  case "$1" in
    -d) [ $# -ge 2 ] || usage; device="$2"; shift 2 ;;
    --cpu) backend=cpu; shift ;;
    *) usage ;;
  esac
done
[ -n "$device" ] || usage

test=integration_test/on_device_measure_test.dart
if [ ! -f "$test" ]; then
  echo "No $test: the ten requests use the example starter's items." >&2
  exit 1
fi

# The device's name, and whether it is an emulator or a simulator.
scratch="$(mktemp -d "${TMPDIR:-/tmp}/measure.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
helper="$scratch/device.dart"
log="$scratch/test.log"
cat > "$helper" <<'DART'
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final devices = jsonDecode(stdin.readLineSync(encoding: utf8) ?? '[]') as List;
  for (final d in devices.cast<Map<String, Object?>>()) {
    if (d['id'] == args.first) {
      stdout.write('${d['emulator'] == true}\t${d['name']}');
      return;
    }
  }
  stdout.write('false\t${args.first}');
}
DART
info="$(flutter devices --machine 2>/dev/null | tr -d '\n' | dart "$helper" "$device")"
emulator="${info%%$'\t'*}"
name="${info#*$'\t'}"

flutter test "$test" -d "$device" --dart-define=BACKEND="$backend" 2>&1 | tee "$log"

pins="$(sed -nE 's/^  (flutter_edge_ai(_litertlm)?): ([0-9.]+)$/\1 \3/p' packages/flutter_agentify_on_device/pubspec.yaml | paste -sd ',' - | sed 's/,/, /g')"
versions="$pins, Gemma 4 E2B b3ca0d2f"
date="$(date +%Y-%m-%d)"

echo
if reason="$(sed -n 's/^.*MEASURE CANNOT RUN \(.*\)$/\1/p' "$log" | head -n 1)" && [ -n "$reason" ]; then
  echo "| $name | | | cannot run the in-app model ($reason) | | | | $date | $versions |"
  exit 0
fi
row="$(sed -n 's/^.*MEASURE ROW \(.*\)$/\1/p' "$log" | head -n 1)"
if [ -z "$row" ]; then
  echo "The measurement did not finish; see the output above." >&2
  exit 1
fi
IFS='|' read -r os used correct first worst peak <<<"$row"
if [ "$emulator" = true ]; then
  echo "| $name (emulator or simulator) | $os | $used | $correct | works; speed not representative | | | $date | $versions |"
else
  echo "| $name | $os | $used | $correct | $first | $worst | $peak | $date | $versions |"
fi
