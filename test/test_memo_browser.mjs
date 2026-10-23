// Il Memo (tabby/memo.html) in un browser vero: Chrome senza finestra, tasti e clic veri
// via DevTools. Uso: node test/test_memo_browser.mjs  (serve Google Chrome)
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
const FILE = new URL("../tabby/memo.html", import.meta.url).pathname;
const DIR = tmpdir() + "/";
const port = 9341;
const chrome = spawn("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [
  "--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${DIR}profilo-memo`, "--window-size=360,420", "about:blank"], { stdio: "ignore" });
const wait = ms => new Promise(r => setTimeout(r, ms));
let list;
for (let i = 0; i < 50; i++) { try { list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json(); if (list.length) break; } catch {} await wait(200); }
const ws = new WebSocket(list.find(t => t.type === "page").webSocketDebuggerUrl);
await new Promise(r => ws.onopen = r);
let id = 0; const pend = new Map();
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m.result); pend.delete(m.id); } };
const send = (method, params = {}) => { const i = ++id; ws.send(JSON.stringify({ id: i, method, params })); return new Promise(r => pend.set(i, r)); };
const ev = async expr => (await send("Runtime.evaluate", { expression: expr, returnByValue: true })).result.value;
await send("Page.enable");
await send("Page.addScriptToEvaluateOnNewDocument", { source: "window.MSG=[];window.webkit={messageHandlers:{tabbymemo:{postMessage:function(o){window.MSG.push(JSON.parse(JSON.stringify(o)))}}}}" });
await send("Page.navigate", { url: "file://" + FILE });
await wait(800);
const KEYS = { Enter: 13, Backspace: 8, Tab: 9, Escape: 27, ArrowUp: 38, ArrowDown: 40 };
async function key(k, mods = 0) {
  const code = KEYS[k];
  await send("Input.dispatchKeyEvent", { type: "rawKeyDown", key: k, code: k, windowsVirtualKeyCode: code, modifiers: mods });
  await send("Input.dispatchKeyEvent", { type: "keyUp", key: k, code: k, windowsVirtualKeyCode: code, modifiers: mods });
  await wait(30);
}
async function type(t) { await send("Input.insertText", { text: t }); await wait(30); }
async function clickMarker(i) {
  const r = await ev(`(function(){var m=document.querySelectorAll('.row')[${i}].querySelector('.mk').getBoundingClientRect();return [m.x+m.width/2,m.y+m.height/2]})()`);
  for (const t of ["mousePressed", "mouseReleased"]) await send("Input.dispatchMouseEvent", { type: t, x: r[0], y: r[1], button: "left", clickCount: 1 });
  await wait(40);
}
const fails = [];
const check = (what, ok) => { console.log((ok ? "  ok   " : "  NO   ") + what); if (!ok) fails.push(what); };
const doc = async () => ev("serialize()");

check("la pagina dice «pronta»", (await ev("JSON.stringify(MSG)")).includes("ready"));
await ev(`setDoc("Spesa\\n- latte\\n[ ] pane\\n> Lavoro\\n  chiamare Marco\\n  mandare preventivo", [])`);
check("righe disegnate: elenco, casella, sezione", await ev(`[...document.querySelectorAll('.row')].map(r=>r.className.split(' ')[1]).join(',')`) === "p,bullet,todo,toggle,p,p");
check("il cursore è in fondo all'ultima riga", await ev(`document.activeElement.textContent`) === "mandare preventivo");

// Invio in fondo all'ultima riga, poi scrivo "- uova": diventa una voce di elenco
await key("Enter"); await type("- uova");
check("«- » a inizio riga diventa un elenco (rientrato nella sezione)", (await doc()).endsWith("  - uova"));
await key("Enter"); await type("burro");
check("Invio su un elenco: nuova voce di elenco", (await doc()).endsWith("  - uova\n  - burro"));
await key("Enter"); await key("Enter");
check("Invio su una voce vuota: l'elenco finisce (riga normale)", (await doc()).endsWith("  - burro\n  "));
await type("[] fattura");
check("«[] » diventa una cosa da fare", (await doc()).endsWith("  [ ] fattura"));
await clickMarker(2);
check("clic sulla casella di «pane»: fatta (barrata)", (await doc()).includes("[x] pane") && await ev(`document.querySelectorAll('.row')[2].classList.contains('done')`));
await clickMarker(3);
check("clic su ▾ «Lavoro»: la sezione si chiude, le sue righe spariscono",
  await ev(`[...document.querySelectorAll('.row')].filter(r=>r.classList.contains('hidden')).length`) === 5);
check("…e Tabby ricorda che è chiusa", (await ev("JSON.stringify(MSG)")).includes('"fold":["Lavoro"]'));
await clickMarker(3);
check("clic su ▸: si riapre", await ev(`document.querySelectorAll('.row.hidden').length`) === 0);
// Cancella a inizio riga su un elenco: torna riga normale
await ev(`place(1, 0)`); await key("Backspace");
check("Cancella a inizio di «latte»: niente più pallino", (await doc()).split("\n")[1] === "latte");
await key("Tab");
check("Tab: «latte» rientra sotto «Spesa»", (await doc()).split("\n")[1] === "  latte");
await key("Tab", 8);
check("Maiusc+Tab: torna indietro", (await doc()).split("\n")[1] === "latte");
await key("Backspace");
check("Cancella a inizio di una riga normale: si unisce a quella sopra", (await doc()).split("\n")[0] === "Spesalatte");
await type(" e ");
await key("ArrowDown");
check("freccia giù: passa alla riga sotto", await ev(`document.activeElement.textContent`) === "pane");
await wait(400);
const saved = await ev("JSON.stringify(MSG.filter(m=>m.text!==undefined).slice(-1)[0])");
check("si salva da solo (testo semplice)", saved && JSON.parse(saved).text === await doc());
await key("Escape");
check("Esc: salva e chiede di chiudere", (await ev("JSON.stringify(MSG.slice(-1)[0])")).includes('"close":true'));
console.log("\nTESTO FINALE:\n" + await doc());
console.log(fails.length ? `\nFALLITI: ${fails.length}` : "\nTUTTO OK");
ws.close(); chrome.kill(); process.exit(0);
