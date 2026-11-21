#!/usr/bin/env bash
# Build the web engine (zig-out/main.wasm) with an optional search budget.
#
#   ./tools/build-wasm.sh                 # default budget, reproduces the committed wasm
#   ./tools/build-wasm.sh 2097152         # deeper search, ~3x slower per late-game move
#   BUDGET=1048576 ./tools/build-wasm.sh
#
# Needs Zig 0.17.x (the README still says 0.16.0 — see docs/wasm-budget.md).
set -euo pipefail
cd "$(dirname "$0")/.."

BUDGET=${1:-${BUDGET:-655360}}
ZIG=${ZIG:-zig}

command -v "$ZIG" >/dev/null || { echo "找不到 zig; 装 Zig 0.17.x 或设 ZIG=/path/to/zig" >&2; exit 1; }

echo "zig    : $("$ZIG" version)"
echo "budget : $BUDGET"

"$ZIG" build --release=fast "-Dbudget=$BUDGET"

bytes=$(stat -c%s zig-out/main.wasm)
echo "wasm   : zig-out/main.wasm  ${bytes}B"
echo "md5    : $(md5sum zig-out/main.wasm | cut -d' ' -f1)"
echo
echo "提示: 换 wasm 之后, 站点侧的 service worker 缓存名要一起改, 否则老客户端继续用旧引擎。"
