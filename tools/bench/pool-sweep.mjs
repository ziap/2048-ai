// Thread-pool scaling of the web build, driven through the repo's own workers:
// js/pool-worker.js (parks inside wasm) + js/worker.js (owns the shared tables).
//
//   node tools/bench/pool-sweep.mjs --wasm zig-out/main.wasm --threads 1,2,4,6,8 --suite dense
//
// Needs a cross-origin-isolated context in a browser, but nothing special here:
// Node worker_threads give us real threads over one shared WebAssembly.Memory.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { Worker } from "./webworker-shim.mjs";
import { DENSE, SPARSE, pack } from "./boards.mjs";

const argv = process.argv.slice(2);
const arg = (name, fallback) => {
    const i = argv.indexOf(name);
    return i >= 0 ? argv[i + 1] : fallback;
};
const root = path.resolve(import.meta.dirname, "../..");
const wasmPath = path.resolve(root, arg("--wasm", "zig-out/main.wasm"));
const threadList = arg("--threads", "1,2,4,6,8").split(",").map(Number);
const suite = arg("--suite", "dense");
const HANDshake_MS = 30000;

const boards = {
    ...(suite === "dense" ? {} : SPARSE),
    ...(suite === "sparse" ? {} : DENSE),
};

const bytes = fs.readFileSync(wasmPath);
const module = await WebAssembly.compile(bytes);
const workerUrl = (file) => pathToFileURL(path.join(root, file)).href;

function spawn(file, payload) {
    const worker = new Worker(workerUrl(file));
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`${file} did not report ready`)), HANDshake_MS);
        worker.onerror = (event) => { clearTimeout(timer); reject(new Error(`${file}: ${event.message}`)); };
        worker.onmessage = (event) => {
            if (event.data === "ready") { clearTimeout(timer); resolve(worker); }
        };
        worker.postMessage(payload);
    });
}

async function measure(threads) {
    const memory = new WebAssembly.Memory({ initial: 1024, maximum: 1024, shared: true });
    const pool = [];
    const started = performance.now();
    for (let i = 0; i < threads - 1; i++) {
        pool.push(await spawn("js/pool-worker.js", { module, memory }));
    }
    const searcher = await spawn("js/worker.js", { module, memory });
    const startup = performance.now() - started;

    const rows = [];
    for (const [name, board] of Object.entries(boards)) {
        const t0 = performance.now();
        const direction = await new Promise((resolve) => {
            searcher.onmessage = (event) => resolve(event.data);
            searcher.postMessage({ board: pack(board), restart: true });
        });
        rows.push({ name, direction, ms: performance.now() - t0 });
    }
    for (const worker of [...pool, searcher]) worker.terminate();
    return { rows, startup };
}

console.log(`${path.relative(root, wasmPath)}  (${bytes.length} bytes), suite=${suite}`);
for (const threads of threadList) {
    const { rows, startup } = await measure(threads);
    const mean = rows.reduce((a, r) => a + r.ms, 0) / rows.length;
    const cell = rows.map((r) => `${r.name.split("-")[0]}:${Math.round(r.ms)}ms`).join(" ");
    console.log(`  threads=${String(threads).padEnd(2)} startup=${String(Math.round(startup)).padStart(5)}ms  均值=${mean.toFixed(1).padStart(6)}ms  ${cell}`);
}
