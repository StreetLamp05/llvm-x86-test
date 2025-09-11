#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# driver for:
#  - docker image build
#  - building llvm-test-suite SingleSource/Benchmarks
#  - timing/space CSV for all built binaries (QEMU by default)
#
# example usage:
#   ./run.sh                # build image, build tests, run under qemu-x86_64
#   ./run.sh --native       # run natively instead of QEMU
#   ./run.sh --timeout 15   # change per-binary timeout (seconds)
#   ./run.sh --rebuild      # force docker image rebuild (no cache)
# ------------------------------------------------------------------------------

IMAGE="llvm-ts:x86"
DOCKERFILE="docker/Dockerfile"
OUT_DIR="out"
RUN_UNDER="qemu"         # "qemu" | "native"
TIMEOUT_SEC="10"
REBUILD="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --native) RUN_UNDER="native"; shift ;;
    --timeout) TIMEOUT_SEC="${2:-10}"; shift 2 ;;
    --rebuild) REBUILD="1"; shift ;;
    -h|--help)
      echo "Usage: $0 [--native] [--timeout N] [--rebuild]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "ERROR: $DOCKERFILE not found. Run from repo root." >&2
  exit 1
fi

echo "Building Docker image: ${IMAGE}"
if [[ "$REBUILD" == "1" ]]; then
  docker build --no-cache -t "$IMAGE" -f "$DOCKERFILE" .
else
  docker build -t "$IMAGE" -f "$DOCKERFILE" .
fi

mkdir -p "$OUT_DIR"

echo "Running container (artifacts -> $OUT_DIR)"
# We mount ./out to persist /workspace/build back to the host
docker run --rm -it \
  -e RUN_UNDER="${RUN_UNDER}" \
  -e TIMEOUT_SEC="${TIMEOUT_SEC}" \
  -v "$PWD/$OUT_DIR":/workspace/build \
  "$IMAGE" \
  bash -lc '
set -euo pipefail
echo "Container RUN_UNDER=${RUN_UNDER:-qemu}, TIMEOUT_SEC=${TIMEOUT_SEC:-10}"

# Build suite
./build-x86.sh


cat >/workspace/run-x86-bench-csv.sh <<'\''CSVEOF'\''
#!/bin/bash
# runs each binary under qemu-x86_64 by default (override with RUN_UNDER=native).
# per-binary timeout configurable using TIMEOUT_SEC (default 10).
# CSV cols:
# name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out

set -u

WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"
OUT_CSV="${BUILD_DIR}/benchmarks.csv"
ROOT="${BUILD_DIR}/SingleSource"
RUN_UNDER="${RUN_UNDER:-qemu}"          # "qemu" or "native"
TIMEOUT_SEC="${TIMEOUT_SEC:-10}"

if [ ! -d "$ROOT" ]; then
  echo "Error: $ROOT not found. Build first." >&2
  exit 1
fi

echo "name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out" > "$OUT_CSV"

# tests
mapfile -t tests < <(cd "$ROOT" && find Benchmarks -type f -name "*.test" | sort)

for t in "${tests[@]}"; do
  test_path="${ROOT}/${t}"
  bin_path="${test_path%.test}"
  name="$(basename "$bin_path")"

  if [ ! -x "$bin_path" ]; then
    echo "${name},${bin_path},,,,,,,,,," >> "$OUT_CSV"
    continue
  fi

  # on-disk size
  file_size="$(stat -c %s "$bin_path" 2>/dev/null || echo "")"

  # section sizes (GNU size): text data bss
  text_bytes="" ; data_bytes="" ; bss_bytes=""
  if size_line="$(size -B "$bin_path" 2>/dev/null | awk '\''NR==2{print $1" "$2" "$3}'\'')"; then
    read -r text_bytes data_bytes bss_bytes <<<"$size_line"
  fi

  # choose runner
  if [ "$RUN_UNDER" = "native" ]; then
    runner=( "$bin_path" )
  else
    runner=( qemu-x86_64 "$bin_path" )
  fi

  # time execution
  elapsed="" ; user="" ; sys="" ; maxrss="" ; exit_code="" ; timed_out=""
  /usr/bin/timeout "${TIMEOUT_SEC}s" /usr/bin/time -f "%e,%U,%S,%M" -o /tmp/time.$$ "${runner[@]}" >/dev/null 2>&1
  ec=$?
  exit_code="$ec"

  if [ -f /tmp/time.$$ ]; then
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
[ "$RUN_UNDER" = "native" ] || echo "Note: timings include qemu-x86_64 overhead."
CSVEOF

chmod +x /workspace/run-x86-bench-csv.sh

# Run CSV pass
./run-x86-bench-csv.sh

# Quick peek
echo
echo "==> Preview (first 10 rows):"
head -n 10 /workspace/build/benchmarks.csv || true

echo "==> Done. Full CSV at /workspace/build/benchmarks.csv"
'

echo
echo "Finished.  CSV is at: ${OUT_DIR}/benchmarks.csv"
echo "if you want native run for comparison ->  ./run.sh --native"
echo "if you want to adjust timeout (seconds) ->   ./run.sh --timeout 20"
