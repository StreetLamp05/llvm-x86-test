#!/bin/bash
# Times executables from llvm-test-suite SingleSource/Benchmarks and writes a CSV.
# CSV columns: name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out

set -u

WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"
OUT_CSV="${BUILD_DIR}/benchmarks.csv"
ROOT="${BUILD_DIR}/SingleSource"

if [ ! -d "$ROOT" ]; then
  echo "Error: $ROOT not found, build first" >&2
  exit 1
fi

echo "name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out" > "$OUT_CSV"

# Collect all .test files under Benchmarks, then map to their sibling executables
mapfile -t tests < <(cd "$ROOT" && find Benchmarks -type f -name "*.test" | sort)

for t in "${tests[@]}"; do
  test_path="${ROOT}/${t}"
  bin_path="${test_path%.test}"
  name="$(basename "$bin_path")"

  # Only measure if the binary exists and is executable
  if [ ! -x "$bin_path" ]; then
    # still emit a row with blanks for metrics
    echo "${name},${bin_path},,,,,,,,,," >> "$OUT_CSV"
    continue
  fi

  # File size
  file_size="$(stat -c %s "$bin_path" 2>/dev/null || echo "")"

  # Section sizes via GNU size => text data bss dec hex file
  text_bytes="" ; data_bytes="" ; bss_bytes=""
  if size_line="$(size -B "$bin_path" 2>/dev/null | awk 'NR==2{print $1" "$2" "$3}')"; then
    read -r text_bytes data_bytes bss_bytes <<<"$size_line"
  fi

  # Time with 10s timeout; capture elapsed (sec), user, sys, max RSS (KB)
  elapsed="" ; user="" ; sys="" ; maxrss="" ; exit_code="" ; timed_out=""
  /usr/bin/timeout 10s /usr/bin/time -f '%e,%U,%S,%M' -o /tmp/time.$$ "$bin_path" >/dev/null 2>&1
  ec=$?
  exit_code="$ec"
  if [ -f "/tmp/time.$$" ]; then
    IFS=, read -r elapsed user sys maxrss < /tmp/time.$$
    rm -f /tmp/time.$$
  fi
  if [ "$ec" -eq 124 ]; then
    timed_out="1"
  else
    timed_out="0"
  fi

  # Emit CSV row
  echo "${name},${bin_path},${file_size},${text_bytes},${data_bytes},${bss_bytes},${elapsed},${user},${sys},${maxrss},${exit_code},${timed_out}" >> "$OUT_CSV"
done

echo "CSV written: $OUT_CSV"
