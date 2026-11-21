// Minimal Web Worker environment for Node, so the browser workers in js/ can be
// driven from a benchmark without a browser. Only used by tools/bench/*.
//
//   node --input-type=module  (imported by the harnesses, not run directly)
//
// It provides: self, postMessage, onmessage, addEventListener/removeEventListener
// ("message", with { once: true } support), a Worker class that maps nested
// workers onto worker_threads, and a navigator.hardwareConcurrency override.
import { Worker as NodeWorker, parentPort, workerData } from "node:worker_threads";
import { pathToFileURL, fileURLToPath } from "node:url";

globalThis.self = globalThis;

try {
    Object.defineProperty(globalThis.navigator ??= {}, "hardwareConcurrency", {
        value: Number(process.env.SHIM_CORES || 4), configurable: true,
    });
} catch {
    Object.defineProperty(globalThis, "navigator", {
        value: { hardwareConcurrency: Number(process.env.SHIM_CORES || 4) }, configurable: true,
    });
}

const listeners = new Map();   // type -> Set<fn>
const once = new WeakSet();
const pending = [];
let handler = null;

function deliver(message) {
    const event = { data: message };
    if (handler) {
        handler(event);
        return;
    }
    const set = listeners.get("message");
    if (!set || set.size === 0) {
        pending.push(message);      // nothing listening yet: keep it, like a browser
        return;
    }
    for (const fn of [...set]) {
        if (once.has(fn)) set.delete(fn);
        fn(event);
    }
}

globalThis.addEventListener = (type, fn, options) => {
    const set = listeners.get(type) ?? new Set();
    listeners.set(type, set);
    set.add(fn);
    if (options?.once) once.add(fn);
    if (type === "message") while (pending.length) deliver(pending.shift());
};

globalThis.removeEventListener = (type, fn) => listeners.get(type)?.delete(fn);

Object.defineProperty(globalThis, "onmessage", {
    get: () => handler,
    set: (fn) => {
        handler = fn;
        if (fn) while (pending.length) deliver(pending.shift());
    },
    configurable: true,
});

globalThis.postMessage = (message) => parentPort?.postMessage(message);

parentPort?.on("message", deliver);

class ShimWorker {
    constructor(url) {
        const target = url instanceof URL ? url : new URL(String(url), pathToFileURL(`${process.cwd()}/`));
        this.thread = new NodeWorker(new URL("./webworker-shim.mjs", import.meta.url), {
            workerData: { modulePath: fileURLToPath(target) },
        });
        this.thread.on("error", (error) => this._onerror?.({ message: error.message }));
    }
    postMessage(message) { this.thread.postMessage(message); }
    terminate() { return this.thread.terminate(); }
    set onmessage(fn) { this._onmessage = fn; this.thread.on("message", (data) => fn({ data })); }
    set onerror(fn) { this._onerror = fn; }
}
globalThis.Worker = ShimWorker;

if (workerData?.modulePath) {
    await import(pathToFileURL(workerData.modulePath).href);
}

export { ShimWorker as Worker };
