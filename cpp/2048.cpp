#include <cmath>
#include <algorithm>
#include <emscripten.h>

#include "board.hpp"

//The key parameter controlling the strength and speed of the AI
#define MIN_DEPTH 3

long long stateEvaled = 0;
Heuristic score(4.0f, 47.0f, 3.5f, 11.0f, 700.0f, 270.0f);
double minProb;

double Expectimax_moveNode(board_t s, unsigned depth, double prob);
double Expectimax_spawnNode(board_t s, unsigned depth, double prob);

double Expectimax_spawnNode(board_t s, unsigned depth, double prob) {
    if (depth <= 0 || prob < minProb) return score.score_heuristic(s) + score.score_heuristic(transpose(s));
    int emptyTiles = count_empty(s);
    prob /= emptyTiles;
    double expect = 0.0;
    for (int i = 0; i < 16; i++) {
        unsigned val = (s >> (60 - 4 * i)) & 0xf;
        if (val != 0) continue;
        expect += Expectimax_moveNode(s | (0x1ULL << (60 - 4 * i)), depth - 1, prob * 0.9) * 0.9;
        expect += Expectimax_moveNode(s | (0x2ULL << (60 - 4 * i)), depth - 1, prob * 0.1) * 0.1;
    }
    return expect / (double)emptyTiles;
}

double Expectimax_moveNode(board_t s, unsigned depth, double prob) {
    stateEvaled++;
    double max = 0;
    for (int i = 0; i < 4; i++) {
        board_t newBoard = move(s, i);
        if (newBoard == s) continue;
        max = std::max(max, Expectimax_spawnNode(newBoard, depth, prob));
    }
    return max;
}

double Expectimax_search(board_t s, int moveDir) {
    board_t newBoard = move(s, moveDir);
    if (newBoard == s) return 0;
    stateEvaled = 0;
    unsigned currentDepth = MIN_DEPTH;
    minProb = 1.0 / (double)(1 << (currentDepth * 2 + 5));
    double result = Expectimax_spawnNode(newBoard, currentDepth, 1);
    unsigned long long minState = 1 << (3 * currentDepth + 5);
    unsigned long long lastStates = 0;

    while ((stateEvaled < minState) && (stateEvaled > lastStates)) {
        currentDepth++;
        minProb = 1.0 / (double)(1 << (currentDepth * 2 + 5));
        minState *= 2;
        lastStates = stateEvaled;
        stateEvaled = 0;
        result = Expectimax_spawnNode(newBoard, currentDepth, 1);
    }
    return result;
}

#ifdef __cplusplus
extern "C" {
#endif
double EMSCRIPTEN_KEEPALIVE jsWork(row_t row1, row_t row2, row_t row3, row_t row4, int dir) {
    return Expectimax_search((board_t(row1) << 48) | (board_t(row2) << 32) | (board_t(row3) << 16) | board_t(row4), dir);
}
#ifdef __cplusplus
}
#endif

int main() {
    emscripten_run_script("onmessage=e=>postMessage(Module._jsWork(e.data.board[0],e.data.board[1],e.data.board[2],e.data.board[3],e.data.dir))");
}