#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
sdk=thirdparty/rexglue-sdk
out=out/tests/linux
mkdir -p "$out"
for name in clocked_audio_sink guest_frame_meter; do
  clang++ -std=c++23 -I"$sdk/include" "tests/native/test_$name.cpp" -o "$out/$name"
  "$out/$name"
done
clang++ -std=c++23 -I"$sdk/include" tests/native/test_frame_limiter.cpp \
  "$sdk/src/graphics/frame_limiter.cpp" -o "$out/frame_limiter"
"$out/frame_limiter"
for profile in goty-compatible goty-us-eu goty-german; do
  clang++ -std=c++23 "-DFABLE2_BUILD_PROFILE=\"$profile\"" \
    tests/native/test_xex_verify.cpp -o "$out/xex-$profile"
  "$out/xex-$profile"
done
