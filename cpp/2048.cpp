#include <cmath>
#include <algorithm>
#include <emscripten.h>

#include "headers/board.hpp"

long long stateEvaled = 0;

heuristic score(4.0f, 47.0f, 3.5f, 11.0f, 700.0f, 270.0f);

float Expectimax_moveNode(board_t s, unsigned depth);
float Expectimax_spawnNode(board_t s, unsigned depth);

float staticEvaluation(board_t s) {
    return score.score_heuristic(s) + score.score_heuristic(transpose(s));
}

float Expectimax_spawnNode(board_t s, unsigned depth) {
    if (depth == 0) return staticEvaluation(s);
    float expect = 0.0f;
    int weight = 0;
    for (int i = 0; i < 16; i++) {
        unsigned val = (s >> (60 - 4 * i)) & 0xf;
        if (val != 0) continue;
        expect += Expectimax_moveNode(s | (0x1ULL << (60 - 4 * i)), depth - 1) * 0.9f;
        expect += Expectimax_moveNode(s | (0x2ULL << (60 - 4 * i)), depth - 1) * 0.1f;
        weight++;
    }
    float score = expect / (float)weight;
    return score;
}

float Expectimax_moveNode(board_t s, unsigned depth) {
    stateEvaled++;
    float max = 0;
    bool moved = false;
    for (int i = 0; i < 4; i++) {
        board_t newBoard = move(s, i);
        if (newBoard == s) continue;
        moved = true;
        max = std::max(max, Expectimax_spawnNode(newBoard, depth));
    }
    if (!moved) return 0;
    return max;
}

float Expectimax_search(board_t s, int moveDir) {
    board_t newBoard = move(s, moveDir);
    if (newBoard == s) return 0;
    stateEvaled = 0;
    unsigned currentDepth = 3;
    float result = Expectimax_spawnNode(newBoard, currentDepth);
    unsigned long long minState = 16384;
    unsigned long long lastStates = 0;

    while ((stateEvaled < minState) && (stateEvaled > lastStates) && (stateEvaled < 16777216)) {
        currentDepth++;
        minState *= 2;
        lastStates = stateEvaled;
        stateEvaled = 0;
        result = Expectimax_spawnNode(newBoard, currentDepth);
    }
    return result;
}

#ifdef __cplusplus
extern "C" {
#endif
float EMSCRIPTEN_KEEPALIVE jsWork(row_t row1, row_t row2, row_t row3, row_t row4, int dir) {
    return Expectimax_search((board_t(row1) << 48) | (board_t(row2) << 32) | (board_t(row3) << 16) | board_t(row4), dir);
}
#ifdef __cplusplus
}
#endif

int main() {
    emscripten_run_script("onmessage=e=>postMessage(Module._jsWork(e.data.board[0],e.data.board[1],e.data.board[2],e.data.board[3],e.data.dir))");
}