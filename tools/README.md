# tools

Small harnesses that measure the engine without a browser. Everything here is
JavaScript run by Node (>= 20.11 for `import.meta.dirname`); no dependencies.

| 文件 | 作用 |
|---|---|
| `build-wasm.sh` | 按指定 `-Dbudget=` 构建 `zig-out/main.wasm`,并打印大小与 md5 |
| `bench/search-budget.mjs` | 单实例、无 worker:给定 wasm 在每个盘面上的单步耗时。调预算时看这个 |
| `bench/pool-sweep.mjs` | 线程池扩展性:用仓库自己的 `js/pool-worker.js` + `js/worker.js`,在一块共享内存上跑 1/2/4/6/8 线程 |
| `bench/boards.mjs` | 两套盘面:稀疏早局(12 个,预算几乎不影响)与密集中残局(4 个,预算说了算) |
| `bench/webworker-shim.mjs` | 在 Node 里模拟 Web Worker(含嵌套 worker、`addEventListener("message", …, {once:true})`),让上面的脚本能驱动浏览器 worker 代码 |

例子:

```sh
./tools/build-wasm.sh 2097152
node tools/bench/search-budget.mjs --suite both --repeat 2
SHIM_CORES=8 node tools/bench/pool-sweep.mjs --threads 1,2,4,6,8 --suite dense
```

`search-budget.mjs` 直接吃 `zig-out/main.wasm`;`pool-sweep.mjs` 走仓库里的 `js/`。
两者都只读文件,不改仓库。
