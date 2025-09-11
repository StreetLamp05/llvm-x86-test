#!/bin/bash
# Times executables from llvm-test-suite SingleSource/Benchmarks and writes a CSV.
# Runs each binary under qemu-x86_64.
# CSV: name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out

set -u

WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"
OUT_CSV="${BUILD_DIR}/benchmarks.csv"
ROOT="${BUILD_DIR}/SingleSource"
RUN_UNDER="${RUN_UNDER:-qemu-x86_64}"   # override with RUN_UNDER=native to run directly

if [ ! -d "$ROOT" ]; then
  echo "Error: $ROOT not found, build first." >&2
  exit 1
fi

echo "name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out" > "$OUT_CSV"

# Collect all .test files under Benchmarks, then map to their sibling executables
mapfile -t tests < <(cd "$ROOT" && find Benchmarks -type f -name "*.test" | sort)

for t in "${tests[@]}"; do
  test_path="${ROOT}/${t}"
  bin_path="${test_path%.test}"
  name="$(basename "$bin_path")"

  if [ ! -x "$bin_path" ]; then
    # emit a row so you can see missing builds
    echo "${name},${bin_path},,,,,,,,,," >> "$OUT_CSV"
    continue
  fi

  # file size on disk
  file_size="$(stat -c %s "$bin_path" 2>/dev/null || echo "")"

  # section sizes via GNU size -> text data bss dec hex file
  text_bytes="" ; data_bytes="" ; bss_bytes=""
  if size_line="$(size -B "$bin_path" 2>/dev/null | awk 'NR==2{print $1" "$2" "$3}')"; then
    read -r text_bytes data_bytes bss_bytes <<<"$size_line"
  fi

  # Choose runner (QEMU or native)
  if [ "${RUN_UNDER}" = "native" ]; then
    runner=( "$bin_path" )
  else
    runner=( qemu-x86_64 "$bin_path" )
  fi

  # Time with 10s timeout; capture elapsed,user,sys,max RSS (KB)
  elapsed="" ; user="" ; sys="" ; maxrss="" ; exit_code="" ; timed_out=""
  /usr/bin/timeout 10s /usr/bin/time -f '%e,%U,%S,%M' -o /tmp/time.$$ "${runner[@]}" >/dev/null 2>&1
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

  echo "${name},${bin_path},${file_size},${text_bytes},${data_bytes},${bss_bytes},${elapsed},${user},${sys},${maxrss},${exit_code},${timed_out}" >> "$OUT_CSV"
done

echo "CSV written: $OUT_CSV"
if [ "${RUN_UNDER}" != "native" ]; then
  echo "Note: timings include qemu-x86_64 overhead (CPU time & RSS reflect emulator+guest)."
fi
