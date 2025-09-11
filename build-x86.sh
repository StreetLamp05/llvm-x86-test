#!/bin/bash
set -e

WORKSPACE="/workspace"
TEST_SUITE_DIR="${WORKSPACE}/llvm-test-suite"
BUILD_DIR="${WORKSPACE}/build"

echo "Building LLVM Test Suite SingleSource/Benchmarks for x86_64 with -O2 optimization"

cd "$BUILD_DIR"

cmake "$TEST_SUITE_DIR" \
  -DTEST_SUITE_SUBDIRS=SingleSource/Benchmarks \
  -DTEST_SUITE_RUN_TYPE=small \
  -DTEST_SUITE_COLLECT_CODE_SIZE=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc \
  -DCMAKE_CXX_COMPILER=g++ \
  -DCMAKE_C_FLAGS="-O2 -Wall -Wextra" \
  -DCMAKE_CXX_FLAGS="-O2 -Wall -Wextra" \
  -DCMAKE_EXE_LINKER_FLAGS="-lm" \
  -GNinja

ninja

echo "Build completed successfully"
echo "Build directory: $BUILD_DIR"

# count built executables 
num_bins=$(find "$BUILD_DIR/SingleSource" -name "*.test" -type f \
  -exec bash -c 'for f; do [[ -x "${f%.test}" ]] && echo "${f%.test}"; done' _ {} + | wc -l)
echo "Total binaries built: $num_bins"

echo
echo "sample binaries:"
find "$BUILD_DIR/SingleSource" -name "*.test" -type f | head -5 | while read -r test_file; do
  binary_file="${test_file%.test}"
  if [ -x "$binary_file" ]; then
    echo "  $(basename "$binary_file") - $(file "$binary_file" | cut -d: -f2-)"
  fi
done
