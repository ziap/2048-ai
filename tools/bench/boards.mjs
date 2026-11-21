// Shared board sets for the benchmarks. Values are tile values (0 = empty);
// they get packed into the engine's 16-nibble BigInt form.
export function pack(board) {
    let packed = 0n;
    for (let r = 0; r < 4; r++) {
        for (let c = 0; c < 4; c++) {
            const value = board[r][c];
            const rank = value === 0 ? 0 : Math.min(15, Math.round(Math.log2(value)));
            packed = (packed << 4n) | BigInt(rank);
        }
    }
    return packed;
}

// Positions with very few tiles: the BFS stops on depth/dedup long before the
// budget matters, so these mostly measure fixed overhead.
export const SPARSE = (() => {
    let seed = 20261120;
    const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
    const pool = [2, 2, 4, 4, 8, 16, 32, 64];
    const boards = {};
    for (let i = 0; i < 12; i++) {
        const board = Array.from({ length: 4 }, () => Array(4).fill(0));
        const tiles = 3 + Math.floor(rnd() * 6);
        for (let k = 0; k < tiles; k++) {
            board[Math.floor(rnd() * 4)][Math.floor(rnd() * 4)] = pool[Math.floor(rnd() * pool.length)];
        }
        boards[`sparse-${String(i + 1).padStart(2, "0")}`] = board;
    }
    return boards;
})();

// Mid/late-game shapes, where the budget actually decides how deep the search
// goes — this is the set worth watching when tuning.
export const DENSE = {
    "late-16384": [[4, 2, 0, 0], [4, 2, 8, 4], [8192, 1024, 128, 8], [16384, 4096, 256, 64]],
    "snake-32768": [[32768, 16384, 8192, 4096], [2048, 1024, 512, 256], [128, 64, 32, 16], [8, 4, 2, 2]],
    "mid-2048": [[0, 2, 8, 32], [2, 128, 512, 256], [64, 1024, 2048, 4], [8, 512, 2, 0]],
    "late-4096": [[2, 4, 0, 0], [4, 2, 0, 0], [4096, 2048, 1024, 512], [8, 4, 2, 0]],
};
