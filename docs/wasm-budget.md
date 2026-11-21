# The web build's search budget (`-Dbudget`)

`BFS_BUDGET` decides how many boards the depth-allocation buffer in
`src/wasm/main.zig` can hold. It is a **ceiling**: `allocDepth()` expands the
frontier breadth-first until the buffer would overflow (or depth/dedup ends it),
and the depth it reaches is the depth the frontier is searched at. A bigger
budget therefore buys deeper search in exactly the positions where that is hard
— the mid and late game.

The console build always had this knob (`-b`, default `2^19`). The web build had
it as a hardcoded constant; this branch turns it into a build option:

```sh
zig build --release=fast -Dbudget=2097152     # or tools/build-wasm.sh 2097152
```

## Zig version

The README says Zig **0.16.0**; that does not build `master` any more.
`0c29695 "Migrate to Zig 0.17"` renamed the `OptimizeMode` fields, and 0.16.0
fails immediately:

```
build.zig:13:30: error: no field named 'fast' in enum 'builtin.OptimizeMode'
  const strip = optimize == .fast or optimize == .small;
```

Use **0.17.x**. With 0.17.1 (aarch64-linux) the default build reproduces the
committed binary **byte for byte**:

```
zig build --release=fast && md5sum zig-out/main.wasm
2c541e988536a7e09c4138fa6313df55   # == the checked-in zig-out/main.wasm
```

so the option is wired in without disturbing the default output.

## Memory

Everything the module needs lives in the single imported, **shared** memory of
`MEMORY_BYTES = 64 MiB` (`build.zig`), and the numbers have to add up:

| consumer | size |
|---|---|
| BFS buffer | `BUDGET * 8` bytes — 5.0 MiB at 655360, 16 MiB at 2097152 |
| transposition table | `2^20` entries * 16 B = 16 MiB (`CACHE_BITS = 20`) |
| move tables | 2 * 65536 * 2 B = 256 KiB |
| pool worker stacks | `MAX_POOL(31) * 256 KiB` = 7.75 MiB (static, even if unused) |

2^21 fits with room to spare; the linker refuses to place data that does not.

## What it costs (single instance, no pool, one 8-core Android device)

Mean per-move time over `tools/bench/search-budget.mjs`:

| budget | wasm | sparse (12) | late-16384 | snake-32768 | mid-2048 | late-4096 | dense mean |
|---|---|---|---|---|---|---|---|
| 655360 (default) | 14831 B | 38.8 ms | 70.7 ms | 73.5 ms | 61.8 ms | 118.2 ms | 81.0 ms |
| 1048576 | 14832 B | 39.3 ms | 96.9 ms | 79.0 ms | 79.1 ms | 117.8 ms | 93.2 ms |
| 2097152 | 14848 B | 65.4 ms | 208.3 ms | 227.1 ms | 217.5 ms | 118.6 ms | 192.9 ms |

Read the columns, not just the means:

- **Sparse early positions barely change** — the BFS stops on depth/dedup long
  before the buffer matters. Raising the budget does not make the opening slow.
- **Dense positions pay ~3x** — that is the intended trade: more search, not
  faster search.
- **`late-4096` does not move at all** (118 ms at every budget) — its expansion
  hits its own depth limit first, which is a good reminder that the budget is a
  ceiling rather than a mandate.
- The wasm itself grows by ~17 bytes: the buffer is uninitialised data, so it
  costs memory, not file size.

For reference, the counts from the README's own benchmark (12 cores, 1000 games)
at the two ends: budget `2^19` → 468,109 average score, 39.1% of games reach
32768; budget `2^21` → 530,970 and 51.7%.

## How to choose

- **Human play**: irrelevant. Nobody notices 70 ms vs 210 ms between their own
  key presses.
- **Autoplay / unattended runs**: this is where it matters. A single-threaded
  web build runs ~5-6 moves/s in a foreground tab (move animation included) and
  ~22-29 moves/s with animations off or in a background tab; at 2^21 the
  per-move cost still fits inside that, so the depth is free at the game level.
- **Add threads, not just budget**: see `docs/thread-pool-notes.md` — 6 threads
  recover most of the latency the deeper budget costs (measured 2.2x), so the
  combination (deep budget + pool) is roughly the default build's speed with
  3.2x the search.
