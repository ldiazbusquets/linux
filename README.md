# Arch Linux in the browser

A full Arch Linux 32 (i686) system running in the browser: https://ldiazbusquets.github.io/linux/
Guided lessons live in the Lab: https://ldiazbusquets.github.io/lab/linux.html

## How it is built

`.github/workflows/pages.yml` runs on every push (and monthly to refresh packages):

1. `build/build-arch.sh` starts an `archlinux` container and runs `build/arch/make-root.sh`, which uses
   `pacstrap` against the [Arch Linux 32](https://archlinux32.org/) i686 repositories, adds a mkinitcpio hook
   that mounts the root filesystem from v86's 9p share, and sets up the `arch` user, autologin on the serial
   console and a few defaults (files in `build/arch/rootfs`).
2. v86's `fs2json.py` and `copy-to-sha256.py` turn the root filesystem into `arch/fs.json` plus
   content-addressed, zstd-compressed files in `arch/flat/`, fetched on demand by the browser.
3. `build/state.mjs` boots it once in Node and saves `arch/state.bin.zst`, so visitors resume a booted machine.
4. `build/test-page.mjs` opens the page in headless Chromium, runs commands, saves and restores.
5. The site (this repo plus `arch/`) is deployed with GitHub Pages from Actions. The image is cached per month.

## Licences

- Emulator: [v86](https://github.com/copy/v86) (BSD-2-Clause), `v86/libv86.js` and `v86/v86.wasm` from the `v86` npm package 0.5.473.
- BIOS: SeaBIOS and the VGA BIOS from the v86 repository (LGPL-3.0, see `v86/LICENSE-seabios.txt`).
- Terminal: [xterm.js](https://xtermjs.org/) 5.5.0 and the fit addon (MIT, `vendor/LICENSE-xterm.txt`).
- Arch Linux 32 packages: each under its own licence, sources available from the Arch Linux 32 project.
  Not affiliated with Arch Linux.
- Fallback image: `v86/linux.iso` from [copy/images](https://github.com/copy/images), Buildroot with Linux 2.6.34
  and BusyBox 1.21 (GPL-2.0), used until the Arch image has been built and by the Lab course and AI terminal.

Everything runs client-side; saves stay in the browser's IndexedDB.
