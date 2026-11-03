# Linux Sandbox

A real Linux system running in the browser, with guided lessons: https://ldiazbusquets.github.io/linux/

- Emulator: [v86](https://github.com/copy/v86) (BSD-2-Clause), `v86/libv86.js` and `v86/v86.wasm` from the `v86` npm package 0.5.473.
- BIOS: SeaBIOS and the VGA BIOS from the v86 repository (LGPL-3.0, see `v86/LICENSE-seabios.txt`).
- Linux image: `v86/linux.iso` from [copy/images](https://github.com/copy/images), a Buildroot build of Linux 2.6.34 with BusyBox 1.21 (GPL-2.0; sources via Buildroot, the Linux kernel and BusyBox projects).

Everything runs client-side; the machine can be saved to the browser's IndexedDB.
