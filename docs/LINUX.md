# Native Linux development build

This checkout ports the source corresponding to the Windows ReXGlue project
at https://github.com/himdo/Fable-2-Recomp. The starting game commit is
`a4b0274`; its pinned SDK is `cc5f03dd0488720a0f277412d7c36b63964d5b18`.
The Linux build uses native ELF executables, SDL3 and Vulkan.
The supplied Windows 1.5.0 binaries are not converted or used by this build.

## Preparing Your Own Game Copy

No copyrighted game files or generated game C++ code are included in this repository. To build and play on Linux with your own copy of **Fable II GOTY (Xbox 360)**:

1. **Extract your Fable II GOTY ISO** into `game-content/` using the included `.NET 8` extractor (or `extract-xiso`):
   ```sh
   dotnet run --project tools/x360extract -c Release -- "/path/to/Fable II (GOTY).iso" -o game-content --files default.xex,data
   ```
2. **Verify your `default.xex` SHA-256**:
   ```sh
   sha256sum game-content/default.xex
   # USA/Europe GOTY: 88c4ef2e18e65409444d1b068eff921d1f7e180a5ae64edc64ba6b0872372662
   ```
3. **Copy `default.xex` to the repository root** for code generation:
   ```sh
   cp game-content/default.xex ./default.xex
   ```
4. **Stage the recomp Lua scripts** into your working content copy:
   ```sh
   mkdir -p game-content/data/scripts/recomp
   cp src/lua/*.lua game-content/data/scripts/recomp/
   ```

## Build

The build currently targets x86-64 Linux with the SDK's x86-64-v2 baseline.
On NixOS, `shell.nix` provides Clang, CMake, Ninja, and graphics/audio headers.
On other distributions, provide equivalent development dependencies and
Clang 18 or newer with C++23 standard-library support.

```sh
git submodule update --init thirdparty/rexglue-sdk
python3 tools/prepare_runtime_sdk.py thirdparty/rexglue-sdk
# Copy your supported GOTY default.xex into the repository root.
nix-shell shell.nix --run ./build-linux.sh
```

`JOBS` controls build parallelism (default 6). Code generation runs first,
then CMake is reconfigured to include the generated source list. The game
executable and shared runtime/plugin are staged in `out/build/linux-release`.
Generated game code and game content must remain local and are ignored by Git.

## Run

```sh
./run-linux.sh
# Or select another working copy of the extracted game content:
FABLE2_GAME_DATA=/path/to/content ./run-linux.sh
```

By default the launcher uses this checkout's `game-content` directory. It
contains a working copy of the supplied USA/Europe GOTY content. Its executable
SHA-256 is `88c4ef2e18e65409444d1b068eff921d1f7e180a5ae64edc64ba6b0872372662`.
Use a working copy: upstream's startup logic may repair `data/dir.manifest`.
Saves, configuration and caches live beside the Linux executable.
The original Windows release and original content directory are separate.

Extra arguments to `run-linux.sh` are passed to the game. For example,
`./run-linux.sh --window_width=1280 --window_height=720`.

## Input and platform differences

Linux uses the SDK SDL keyboard/mouse driver and SDL controllers. Default
keyboard mappings include WASD movement, E/Space for A, B/middle mouse for B,
left/right mouse for X/Y, Q/R for triggers, Z/Tab for shoulders, arrows for
the D-pad, Escape/Return for Start, and M for Back. Change the SDK `keybind_*`
settings in `fable_2.toml` or command-line overrides. The Windows-specific
`keyboard_gamepad_map` does not control the Linux driver. Mouse input uses
the SDK's `mnk_mouse` and `mnk_sensitivity` settings.

Windows VEH crash logging, suspended-thread stall dumping and the optional
SEH heap scanner are excluded on Linux. F5 Lua hotkey polling is currently
Windows-only. The WPF Windows launcher is not part of the Linux build.

## Checks

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
nix-shell shell.nix --run tests/run_native_tests.sh
```

The native checks cover audio pacing, frame metering/limiting and supported
game-version validation. Passing these checks does not establish gameplay
or Vulkan rendering correctness; that requires running the game.
