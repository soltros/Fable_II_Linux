#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ ! -f default.xex ]]; then
  echo 'Place your supported GOTY default.xex in this source directory first.' >&2
  exit 1
fi
build_dir="${FABLE2_BUILD_DIR:-out/build/linux-release}"
cmake_args=(
  -S . -B "$build_dir" -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
  -DCMAKE_C_FLAGS=-march=x86-64-v2 -DCMAKE_CXX_FLAGS=-march=x86-64-v2
  -DREXSDK_DIR="$PWD/thirdparty/rexglue-sdk"
  -DREXGLUE_USE_VULKAN=ON -DREXGLUE_USE_D3D12=OFF
  -DREXGLUE_ENABLE_TRACY=OFF -DREXGLUE_BUILD_TESTS=OFF
)
cmake "${cmake_args[@]}"
# The generated source list becomes available only after the initial codegen.
cmake --build "$build_dir" --target fable_2_codegen --parallel "${JOBS:-6}"
cmake "${cmake_args[@]}"
cmake --build "$build_dir" --target fable_2 --parallel "${JOBS:-6}"
