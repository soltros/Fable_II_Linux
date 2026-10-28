# Fable 2 for Linux

An experimental native Linux port of [himdo/Fable-2-Recomp](https://github.com/himdo/Fable-2-Recomp), built with the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk).

This is a standalone, independently maintained source repository. It recompiles the Xbox 360 PowerPC executable into C++ and builds an x86-64 Linux executable, using SDL3 for platform integration and Vulkan for graphics. The Linux build does not require Wine, Proton, or the Windows launcher.

**Status: development and validation in progress.** A successful build is not a claim that the game is fully playable. See [validation](#validation) and [known limitations](#known-limitations) before relying on this port.

No original game executable, disc image, assets, saves, or generated game code are distributed here. You must provide your own supported Fable II GOTY game files.

## What this repository changes

- Adds a native Linux build script that bootstraps the SDK and game code generation, then compiles the application and Vulkan GPU plugin.
- Provides a Nix development environment with Clang, CMake, Ninja, and Linux audio/window-system dependencies.
- Stages the Linux shared runtime alongside the executable so the host can locate it through its relative library search path.
- Fixes application access to the SDK's ImGui headers when building the SDK directly from source.
- Replaces the Windows-only frame-limiter pause with a Linux thread yield.
- Excludes optional Windows exception-handler and suspended-thread diagnostics from the Linux build.
- Uses the SDK's SDL keyboard/mouse driver on Linux, with game-oriented default bindings.
- Adds a Linux launch script and a native test runner.

The Windows source and upstream documentation are retained. The original Windows README is archived in [README.windows.md](README.windows.md); its Windows-specific instructions and historical compatibility claims do not establish Linux support.

## Architecture

```text
Your supported default.xex
           |
           v
ReXGlue codegen + game manifest + recomp patches
           |
           v
Generated C++ + game hooks + native platform code
           |
           v
Linux fable_2 executable
   |               |                 |
ReXGlue runtime    SDL3          Xenos Vulkan plugin
   |               |                 |
Xbox services   Input/window/audio   Vulkan driver
           |
           v
Your extracted game data
```

The recompilation replaces execution of the PowerPC instruction stream with compiled host code. The runtime still implements Xbox 360 services, and the Xenos GPU plugin translates the game's graphics commands. This is not a replacement renderer or a reconstruction of the game in another engine.

## Requirements

- x86-64 Linux with an x86-64-v2-capable CPU.
- A Vulkan-capable GPU and a functioning Linux Vulkan driver. Actual compatibility depends on the features required by the SDK renderer.
- X11 or Wayland with the required SDL dependencies.
- Clang 18 or newer and a C++23-capable standard library.
- CMake 3.25 or newer, Ninja, Python 3, Git, and pkg-config.
- Development headers for X11/XCB, Wayland, xkbcommon, libdecor, ALSA, PulseAudio, PipeWire, udev, and Vulkan. The exact Nix dependency list is in [shell.nix](shell.nix).
- Your own supported GOTY `default.xex` and extracted `data/` directory.

The initial build is substantial: the game generates approximately 309 MB of C++ across hundreds of translation units. Dependencies, build products, and a separate content copy also consume disk space. The build defaults to six parallel jobs; lower `JOBS` if memory is limited.

## Playing with your own copy of the game (Quick Start)

Because this repository distributes **no original game executables (`default.xex`), disc images, assets, or generated game C++ code**, you build and run the port locally using your own legally obtained **Fable II Game of the Year Edition (GOTY)** Xbox 360 disc dump.

### Step 1: Extract your Fable II GOTY disc ISO

If you have a raw Xbox 360 disc image (`.iso`) of a supported Fable II GOTY edition, you can extract `default.xex` and `data/` directly on Linux using the included [`tools/x360extract`](tools/x360extract/README.md) utility (requires the .NET 8 SDK) or an external Xbox 360 GDFX extractor (`extract-xiso`, XexTool, etc.):

```sh
# Option A: Using the included .NET 8 x360extract tool directly into game-content/
dotnet run --project tools/x360extract -c Release -- "/path/to/Fable II (GOTY).iso" -o game-content --files default.xex,data

# Option B: Using extract-xiso
mkdir -p game-content
extract-xiso -d game-content "/path/to/Fable II (GOTY).iso"
```

Keep a clean backup of your extracted files, as startup logic can update `data/dir.manifest` in your working directory.

### Step 2: Verify your `default.xex` edition

Check the SHA-256 checksum of your extracted `default.xex`:

```sh
sha256sum game-content/default.xex
```

Compare it against the supported GOTY editions in [`constants/game_versions.json`](constants/game_versions.json):

| Edition | Profile ID | `default.xex` Size | SHA-256 |
| --- | --- | --- | --- |
| **GOTY USA/Europe** (primary tested) | `goty-us-eu` | `21,217,280` bytes | `88c4ef2e18e65409444d1b068eff921d1f7e180a5ae64edc64ba6b0872372662` |
| **GOTY German** | `goty-german` | `21,217,280` bytes | `3f36e7870a06e04b3702760e93c61b1c7fded321b94021da6bfa120b424e6eb4` |
| **GOTY France** | `goty-french` | `21,217,280` bytes | `0e1ea96ded3407874cbbb3a9587d79f1340a57a9d1ba2feebcfdbc9ed1e4b6e5` |
| **GOTY Italy** | `goty-italy` | `21,217,280` bytes | `27a7ad9d66df4131a7fc352829d9df4df40206350ec63c7ee1b53bd71b203da0` |
| **GOTY Spain** | `goty-spain` | `21,217,280` bytes | `6422e22327b576f6d188206ab00112eedc780f3d130a45ca6ac42f7e4b99da6c` |
| **GOTY Russia** | `goty-russia` | `21,217,280` bytes | `aaf100ce83994d178c6585ab502babfd6b3c9d0739017e96e6e5d61bcbbca943` |

> **Note:** For code generation (`fable_2_codegen`), use the **USA/Europe GOTY** `default.xex` (`88c4ef2e...`) in the repository root, or a compatible GOTY edition whose code payload matches. Base retail / TU1 discs (`21,053,440` bytes) have a different binary layout and are **not** supported.

The expected content layout in `game-content/` is:

```text
game-content/
  default.xex
  data/
    dir.manifest
    gold_version.txt
    startup.vfsconfig
    ...the rest of your extracted data...
```

### Step 3: Stage `default.xex` for recompilation and build

Copy `default.xex` to the repository root so ReXGlue can translate the PowerPC binary into C++ during the build:

```sh
cp game-content/default.xex ./default.xex
```

Initialize the SDK submodule and run the Linux build (see [Build on NixOS](#build-on-nixos) or [Build on other Linux distributions](#build-on-other-linux-distributions) below for dependency details):

```sh
git submodule update --init thirdparty/rexglue-sdk
python3 tools/prepare_runtime_sdk.py thirdparty/rexglue-sdk
./build-linux.sh   # or: nix-shell shell.nix --run ./build-linux.sh
```

### Step 4: Stage helper scripts and play

Copy the project's recomp Lua scripts into your `game-content/` directory and launch:

```sh
mkdir -p game-content/data/scripts/recomp
cp src/lua/*.lua game-content/data/scripts/recomp/
./run-linux.sh
```

---

## Build on NixOS

Clone the source and fetch the pinned SDK:

```sh
git clone https://github.com/soltros/Fable_II_Linux.git
cd Fable_II_Linux
git submodule update --init thirdparty/rexglue-sdk
python3 tools/prepare_runtime_sdk.py thirdparty/rexglue-sdk
```

The preparation script validates the expected SDK fixes and fetches its dependencies. Network access is needed on the first run.

Copy your supported executable into the repository root for code generation:

```sh
cp /path/to/your/extracted-game/default.xex ./default.xex
```

Build:

```sh
nix-shell shell.nix --run ./build-linux.sh
```

To reduce memory use:

```sh
JOBS=2 nix-shell shell.nix --run ./build-linux.sh
```

The script configures the source SDK, builds and runs the recompiler, reconfigures CMake after the generated source list exists, and builds the game. Incremental runs reuse existing build products. The default build directory is `out/build/linux-release`; `FABLE2_BUILD_DIR` can override it.

The Nix shell uses the caller's `<nixpkgs>` selection. It is a development environment, not a pinned redistributable binary package.

## Build on other Linux distributions

Install the development dependencies listed above, ensuring `clang`, `clang++`, `cmake`, `ninja`, `python3`, and `pkg-config` are available. Then use the same checkout, SDK preparation, and executable-copy steps, followed by:

```sh
./build-linux.sh
```

Distribution-specific package names vary. SDL configuration errors identify missing platform development packages. NixOS is the initial development environment; other distributions require independent verification.

## Prepare a working content copy

After building, prepare a separate writable content directory:

```sh
mkdir -p game-content
cp -a /path/to/your/extracted-game/default.xex game-content/
cp -a /path/to/your/extracted-game/data game-content/
mkdir -p game-content/data/scripts/recomp
cp src/lua/*.lua game-content/data/scripts/recomp/
```

This content is ignored by Git and must not be uploaded with the source.

## Launch

```sh
./run-linux.sh
```

The launcher defaults to `game-content/`, starts in windowed mode, and changes the working directory to the build output. It also exposes the system Vulkan loader and active graphics-driver directory on NixOS.

Select another content copy or pass presentation settings:

```sh
FABLE2_GAME_DATA=/path/to/working-copy ./run-linux.sh
./run-linux.sh --window_width=1280 --window_height=720
./run-linux.sh --fullscreen=true
```

Arguments after the script name are forwarded to the game. For direct invocation, run the `fable_2` binary with `--game_data_root=/absolute/path/to/content` and ensure its shared libraries and Vulkan loader can be found.

The Linux build output contains the native executable, shared runtime and GPU plugin, configuration templates, and staged project scripts/artwork. It does not automatically contain your original game content.

## Controls

Controllers use the SDK's SDL gamepad support. Linux keyboard/mouse emulation uses the SDK's `mnk_*` and `keybind_*` settings.

| Action | Default binding |
| --- | --- |
| Move | W, A, S, D |
| A button | E or Space |
| B button | B or middle mouse |
| X button | Left mouse |
| Y button | Right mouse |
| Left/right trigger | Q / R |
| Left/right shoulder | Z / Tab |
| D-pad | Arrow keys |
| Start | Escape or Return |
| Back | M |
| Camera | Mouse movement |

Set `mnk_mode=false` to disable keyboard/mouse emulation. `mnk_mouse` controls mouse look and `mnk_sensitivity` controls its sensitivity. Customize `keybind_*` values in the SDK configuration or through command-line overrides.

The Windows `keyboard_gamepad_map` setting does not drive the Linux SDL input path. The Linux defaults use Space in place of the Windows Shift-to-A mapping because the SDK treats modifier keys differently.

## Configuration, saves, and logs

- `fable2_config.toml`: game-specific options and patches.
- `fable_2.toml`: SDK configuration, including Linux input bindings and graphics options.
- `saves/`: game saves beside the executable; back this directory up.
- Runtime logs and caches are also created beside the executable.

Configuration values supplied through the SDK configuration, environment, or command line take precedence over seeded defaults. Build scripts preserve existing user configuration rather than overwriting it on each build.

To report a problem, include the source revision, SDK revision, GPU/driver, desktop session type, game edition, exact launch command, and relevant log excerpts. Do not attach game files or personal saves to public issues.

## Validation

Run the source checks:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
nix-shell shell.nix --run tests/run_native_tests.sh
```

Without Nix, run `tests/run_native_tests.sh` in the prepared compiler environment.

The initial development run passed all seven Python checks and the native audio pacing, guest frame metering, frame limiter, and version/content-validation checks for `goty-compatible`, `goty-us-eu`, and `goty-german`. These are synthetic checks; they do not validate a complete playthrough or GPU rendering.

Build and runtime validation results will be recorded here when the initial Linux launch investigation finishes.

## Known limitations

- Linux gameplay and rendering are experimental until verified. Upstream Windows playability claims do not transfer automatically.
- The Vulkan backend is a different rendering path from the Windows release's default Direct3D 12 backend.
- The WPF Windows launcher and its ISO-extraction interface are not ported; supply an extracted content tree.
- Optional Windows VEH crash logging, thread-suspension stall diagnostics, and SEH heap scanning are disabled on Linux.
- The game's custom F5 Lua hotkey polling remains Windows-only.
- Linux keyboard configuration currently uses the SDK bindings rather than the Windows-specific mapping string.
- A Nix-built executable depends on libraries in the Nix store. Copying the output directory alone does not make a portable distribution package.
- No AppImage, Flatpak, Steam Deck certification, or Linux binary release is provided by this source port at this stage.

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/` | Game integration, hooks, patches, input, diagnostics |
| `fable_2_manifest.toml` | Recompiler configuration and function metadata |
| `constants/` | Verified executable/edition catalog |
| `thirdparty/rexglue-sdk/` | Pinned SDK source submodule |
| `tools/` | SDK preparation, code-generation patches, supporting utilities |
| `tests/` | Source and native checks |
| `build-linux.sh` | Linux build entry point |
| `run-linux.sh` | Linux launch entry point |
| `shell.nix` | Nix development environment |
| `docs/` | Linux notes and upstream technical documentation |
| `generated/` | Locally generated code; not distributed, except the build integration file |
| `game-content/` | Local game content; never distributed |
| `out/` | Local build/test products |

## Provenance and licensing

This source starts from `himdo/Fable-2-Recomp` commit `a4b0274` and its pinned SDK commit `cc5f03dd0488720a0f277412d7c36b63964d5b18`. The SDK submodule currently points to [himdo/rexglue-sdk](https://github.com/himdo/rexglue-sdk), which carries the runtime fixes used by the game project.

Credit for the recompilation project, manifests, game patches, and original Windows integration belongs to its upstream contributors. ReXGlue and the underlying Xenia work provide the runtime and graphics foundations. See the upstream documentation and individual source-file notices for additional attribution.

The project source retains its upstream [MIT license](LICENSE). The SDK and vendored dependencies carry their own licenses and notices. The original game and its assets are not licensed by this repository and are not included.
