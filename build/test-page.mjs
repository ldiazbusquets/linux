// Opens the deployed page in headless Chromium, runs commands in Arch, then checks Save + restore.
import { chromium } from "playwright";
const URL = process.argv[2] || "http://localhost:8000/";
const t0 = Date.now(), secs = () => ((Date.now() - t0) / 1000).toFixed(1) + "s";
const b = await chromium.launch();
const page = await b.newPage({ viewport: { width: 1280, height: 800 } });
page.on("pageerror", e => console.log("PAGE ERROR", e.message));
page.on("console", m => { if (m.type() === "error") console.log("CONSOLE", m.text()); });
const screen = () => page.evaluate(() => { const bf = __linux.term.buffer.active, o = []; for (let i = 0; i < bf.length; i++) o.push(bf.getLine(i).translateToString(true)); return o.join("\n").replace(/\n+$/, ""); });
async function run(cmd, marker, ms = 60000) {
  await page.evaluate(c => __linux.send(c + "\r"), cmd);
  await page.waitForFunction(m => { const bf = __linux.term.buffer.active; for (let i = 0; i < bf.length; i++) if (bf.getLine(i).translateToString(true).startsWith(m)) return true; return false; }, marker, { timeout: ms });
}
async function boot(label) {
  await page.goto(URL);
  await page.waitForFunction(() => window.__linux && __linux.booted && __linux.ready, null, { timeout: 240000 });
  await page.waitForTimeout(1500);
  console.log(`== ${label}: booted in ${secs()} (mode ${await page.evaluate(() => __linux.mode)}, status "${await page.textContent("#state")}")`);
}
try {
  await boot("first visit");
  await run("whoami; uname -mr; grep PRETTY /etc/os-release; sudo -n true && echo SUDO_OK; python -c 'print(6*7)'; pacman -Ss '^vim$' | head -2; pacman -Q | wc -l; df -h / | tail -1; echo HELLO > ~/kept.txt; echo T1_DONE", "T1_DONE", 120000);
  console.log(await screen());
  await page.click("#bSave");
  await page.waitForFunction(() => /saved/.test(document.querySelector("#state").textContent), null, { timeout: 180000 });
  console.log(`== saved at ${secs()}: ${await page.textContent("#toast")}`);
  await page.screenshot({ path: "shot.png" });
  await boot("reload");
  await run("cat ~/kept.txt; echo T2_DONE", "T2_DONE");
  const s = await screen();
  console.log(s.split("\n").slice(-6).join("\n"));
  console.log(s.includes("HELLO") ? "== RESTORE OK" : "== RESTORE FAILED");
} catch (e) {
  console.log("== TEST FAILED at " + secs() + ": " + e.message);
  try { console.log(await screen()); } catch (_) {}
}
await b.close();
