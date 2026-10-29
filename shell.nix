{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell.override { stdenv = pkgs.llvmPackages.stdenv; } {
  nativeBuildInputs = with pkgs; [ cmake ninja pkg-config python3 git llvmPackages.lld wayland-scanner ];
  buildInputs = with pkgs; [
    vulkan-loader vulkan-headers libGL wayland wayland-protocols libxkbcommon
    libdecor alsa-lib libpulseaudio pipewire udev
    libX11 libXext libXcursor libXi libXfixes libXrandr libXScrnSaver libxcb libXtst
  ];
}
