# Thread pool: scaling and startup robustness

Numbers below are from `tools/bench/pool-sweep.mjs`, which drives the repo's own
`js/pool-worker.js` + `js/worker.js` in Node `worker_threads` (real threads over
one shared `WebAssembly.Memory`), on an 8-core Android device (aarch64),
default budget (`BFS_BUDGET = 655360`), dense mid/late-game boards.

## Scaling

| threads | startup | mean | late-16384 | snake-32768 | mid-2048 | late-4096 |
|---|---|---|---|---|---|---|
| 1 | 93ms | 80.3ms | 71ms | 72ms | 61ms | 117ms |
| 2 | 168ms | 49.7ms | 43ms | 56ms | 36ms | 64ms |
| 4 | 260ms | 43.0ms | 40ms | 59ms | 32ms | 41ms |
| 6 | 374ms | 36.1ms | 29ms | 57ms | 25ms | 34ms |
| 8 | 520ms | 37.4ms | 29ms | 54ms | 25ms | 42ms |

- About **2.2x** at 6 threads; 8 threads is not better on a 4+4 core phone —
  the two extra threads only add contention.
- The gain is bounded by how narrow the split is. `snake-32768` (72 → 54ms) has
  a small frontier, so a good part of its work stays serial on the searching
  worker; the wider positions get ~2.5-3.4x.
- Startup grows roughly linearly (93 → 520ms): every pool worker fetches
  `js/pool-worker.js` for itself.

## Startup robustness (a real hole in `js/main.js`)

Symptom seen in practice: on a slow link the page can sit for seconds before the
first move — and if one pool-worker script fetch hangs, `createWorker()` never
resolves, nothing throws, and the page simply does nothing forever.

Measured over a Cloudflare quick tunnel (cold cache, 8 threads): **2.7-5.1s**
until `ready`; in one run no worker reported ready inside 4s even though the
seven script requests had all been issued.

Root cause: `js/main.js` spawns `threads - 1` pool workers **in parallel**, each
one fetching `js/pool-worker.js` over the network, and awaits `'ready'` from all
of them **without any timeout**.

Four changes that fix it (all measured on our own build, same wasm, same tunnel):

| change | effect |
|---|---|
| per-worker handshake timeout (6s) | a hung fetch degrades instead of hanging |
| `Promise.allSettled` instead of `Promise.all` | keeps whichever workers did come up — a partial pool is a valid configuration |
| fetch the pool script **once** and derive every worker from a Blob URL | 7 network fetches → 1: cold 5.1s → 2.2s, warm 0.9s, localhost 1.14s → 0.66s |
| an initialisation watchdog (20s) | worst case the caller gets an error instead of waiting forever |

Why a partial pool is safe: `poolWorker()` only claims a stack once it is
spawned (up to `MAX_POOL = 31`), and the searching worker drains the batch queue
itself in `finalize()`, so N-1 workers for any N ≥ 1 is a legal configuration —
just slower.

Also worth knowing when hosting this yourself: the pool needs cross-origin
isolation (`Cross-Origin-Opener-Policy: same-origin` +
`Cross-Origin-Embedder-Policy: require-corp`), because the module imports a
**shared** memory, and that memory has to be created with
`initial == maximum == 1024` pages, exactly like `js/main.js` does.
