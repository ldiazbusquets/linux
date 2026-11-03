// Boots the built Arch image once in Node and saves a snapshot right after login,
// so the page can resume it in a couple of seconds instead of booting from scratch.
// Usage: node build/state.mjs ARCH_DIR V86_DIR   (writes ARCH_DIR/state.bin.zst)
import { V86 } from "v86";
import fs from "node:fs";
import path from "node:path";
import url from "node:url";
import { execFileSync } from "node:child_process";

const [dir, biosDir] = process.argv.slice(2).map(p => path.resolve(p));
const wasm = path.join(path.dirname(url.fileURLToPath(import.meta.resolve("v86"))), "v86.wasm");
// Keep in sync with HW in index.html: a snapshot only restores on identical hardware.
const emu = new V86({
  wasm_path: wasm,
  bios: { url: path.join(biosDir, "seabios.bin") },
  vga_bios: { url: path.join(biosDir, "vgabios.bin") },
  memory_size: 384 * 1024 * 1024,
  vga_memory_size: 8 * 1024 * 1024,
  net_device: { type: "virtio" },
  filesystem: { basefs: { url: path.join(dir, "fs.json") }, baseurl: path.join(dir, "flat") + "/" },
  bzimage_initrd_from_filesystem: true,
  cmdline: "rw root=host9p rootfstype=9p rootflags=trans=virtio,cache=loose console=ttyS0 init_on_free=on spectre_v2=off pti=off quiet loglevel=3",
  autostart: true,
  screen_dummy: true,
  disable_speaker: true,
});

const t0 = Date.now();
let out = "", stage = 0;
const strip = s => s.replace(/\x1b\[[0-9;?]*[A-Za-z]|\x1b[78]/g, "");
emu.add_listener("serial0-output-byte", b => {
  const c = String.fromCharCode(b);
  process.stdout.write(c);
  out += c;
  if (out.length > 20000) out = out.slice(-5000);
  const s = strip(out);
  if (stage === 0 && /arch@arch \S* \$ $/.test(s)) {
    stage = 1;
    console.error(`\n== logged in after ${(Date.now() - t0) / 1000}s`);
    setTimeout(() => emu.serial0_send("sudo dmesg -n 1; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null; echo LDB_READY_$((6*7))\n"), 3000);
  }
  if (stage === 1 && s.includes("LDB_READY_42")) {
    stage = 2;
    setTimeout(async () => {
      const st = new Uint8Array(await emu.save_state());
      const raw = path.join(dir, "state.bin");
      fs.writeFileSync(raw, st);
      execFileSync("zstd", ["-15", "--long=27", "-f", "-q", "--rm", raw, "-o", raw + ".zst"], { stdio: "inherit" });
      console.error(`== snapshot ${(st.length / 1e6).toFixed(0)} MB raw, ${(fs.statSync(raw + ".zst").size / 1e6).toFixed(1)} MB compressed`);
      emu.destroy ? await emu.destroy() : emu.stop();
      process.exit(0);
    }, 3000);
  }
});
setTimeout(() => { console.error("\n== timed out waiting for login"); process.exit(1); }, 25 * 60 * 1000);
