// Per-move search latency of a given main.wasm, single instance, no workers.
// This is the measurement that shows what `-Dbudget=` buys and costs.
//
//   node tools/bench/search-budget.mjs --wasm zig-out/main.wasm --suite both --repeat 3
import fs from "node:fs";
import path from "node:path";
import { DENSE, SPARSE, pack } from "./boards.mjs";

const argv = process.argv.slice(2);
const arg = (name, fallback) => {
    const i = argv.indexOf(name);
    return i >= 0 ? argv[i + 1] : fallback;
};
const root = path.resolve(import.meta.dirname, "../..");
const wasmPath = path.resolve(root, arg("--wasm", "zig-out/main.wasm"));
const suite = arg("--suite", "both");
const repeat = Number(arg("--repeat", "1"));

const boards = {
    ...(suite === "dense" ? {} : SPARSE),
    ...(suite === "sparse" ? {} : DENSE),
};

const bytes = fs.readFileSync(wasmPath);
const memory = new WebAssembly.Memory({ initial: 1024, maximum: 1024, shared: true });
const { instance } = await WebAssembly.instantiate(bytes, { env: { memory } });
const engine = instance.exports;
engine.init();

const rows = [];
for (const [name, board] of Object.entries(boards)) {
    const packed = pack(board);
    engine.reset_depth();
    const times = [];
    let direction = null;
    for (let i = 0; i < repeat; i++) {
        const t0 = performance.now();
        direction = engine.search(packed);
        times.push(performance.now() - t0);
    }
    const mean = times.reduce((a, b) => a + b, 0) / times.length;
    rows.push({ name, direction, mean, company: times.map((t) => Math.round(t)).join("/") });
}

console.log(`${path.relative(root, wasmPath)}  (${bytes.length} bytes)`);
for (const row of rows) {
    console.log(`  ${row.name.padEnd(16)} dir=${String(row.direction).padStart(2)}  mean=${row.mean.toFixed(1).padStart(6)}ms  ${row.company}`);
}
const dense = rows.filter((r) => r.name.startsWith("late") || r.name.startsWith("snake") || r.name.startsWith("mid"));
const avg = (list) => list.reduce((a, b) => a + b.mean, 0) / (list.length || 1);
console.log(`  均值: 稀疏 ${avg(rows.filter((r) => r.name.startsWith("sparse"))).toFixed(1)}ms, 密集 ${avg(dense).toFixed(1)}ms`);
