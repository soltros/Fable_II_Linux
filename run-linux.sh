#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
build_dir="${FABLE2_BUILD_DIR:-$root/out/build/linux-release}"
content="${FABLE2_GAME_DATA:-$root/game-content}"
if [[ ! -x "$build_dir/fable_2" ]]; then
  echo 'Linux executable is missing. Run nix-shell --run ./build-linux.sh first.' >&2
  exit 1
fi
if [[ ! -f "$content/default.xex" || ! -d "$content/data" ]]; then
  echo 'Set FABLE2_GAME_DATA to an extracted supported GOTY content directory.' >&2
  exit 1
fi
# NixOS exposes the active graphics driver and system Vulkan loader here.
lib_paths=()
if [[ -d /run/opengl-driver/lib ]]; then
  lib_paths+=("/run/opengl-driver/lib" "/run/current-system/sw/lib")
fi
if [[ -f "$build_dir/.nix-lib-path" ]]; then
  lib_paths+=("$(<"$build_dir/.nix-lib-path")")
fi
if (( ${#lib_paths[@]} > 0 )); then
  joined=$(IFS=:; echo "${lib_paths[*]}")
  export LD_LIBRARY_PATH="${joined}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
cd -- "$build_dir"
exec ./fable_2 --game_data_root="$content" --fullscreen=false "$@"
