#include "headers/cache.hpp"
#include "headers/lookup.hpp"
#include "headers/board.hpp"
#include "headers/moveTable.hpp"
#include "headers/revTable.hpp"

#include <emscripten.h>

lookup score({4.0f, 47.0f, 3.5f, 11.0f, 700.0f, 270.0f, 1.0f, 0.0f});

int stateEvaled = 0;

float Expectimax_moveNode(board_t s, unsigned depth);
float Expectimax_spawnNode(board_t s, unsigned depth);

board_t moveLeft(board_t s) {
    return (board_t(moveTable[s & 0xffff]) |
           (board_t(moveTable[(s >> 16) & 0xffff]) << 16) |
           (board_t(moveTable[(s >> 32) & 0xffff]) << 32) |
           (board_t(moveTable[(s >> 48) & 0xffff]) << 48));
}

board_t moveRight(board_t s) {
    return (board_t(revTable[s & 0xffff]) |
           (board_t(revTable[(s >> 16) & 0xffff]) << 16) |
           (board_t(revTable[(s >> 32) & 0xffff]) << 32) |
           (board_t(revTable[(s >> 48) & 0xffff]) << 48));
}

board_t moveUp(board_t s) {
    return board::transpose(moveLeft(board::transpose(s)));
}

board_t moveDown(board_t s) {
    return board::transpose(moveRight(board::transpose(s)));
}

board_t addTile(board_t s) {
    int randomPos = rand() % 16;
    while (((s >> (60 - 4 * randomPos)) & 0xf) != 0) randomPos = rand() % 16;
    return ((rand() % 10) ? (s | (0x1ULL << (60 - 4 * randomPos))) : (s | (0x2ULL << (60 - 4 * randomPos))));
}

board_t move(board_t s, int dir) {
    switch (dir)
    {
        case 0: return moveUp(s);
        case 1: return moveRight(s);
        case 2: return moveDown(s);
        case 3: return moveLeft(s);
        default: return s;
    }
}

float staticEvaluation(board_t s) {
    /*if (score.losing(s) && score.losing(transpose)) return 0;
    else*/ return score.heuristic(s) + score.heuristic(board::transpose(s));
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
    if (weight > 0) return expect / (float)weight;
    else return 0;
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

float Expectimax_search(board_t s, int moveDir, int depth) {
    board_t newBoard = move(s, moveDir);
    if (newBoard == s) return 0;
    stateEvaled = 0;
    return Expectimax_spawnNode(newBoard, depth);
}

extern "C" {

float jsWork(row_t row1, row_t row2, row_t row3, row_t row4, int dir, int depth) {
    return Expectimax_search((board_t(row1) << 48) | (board_t(row2) << 32) | (board_t(row3) << 16) | board_t(row4), dir, depth);
}

int nodes() {
    return stateEvaled;
}

}

int main() {
    emscripten_run_script("onmessage=e=>postMessage({result:Module._jsWork(e.data.board[0],e.data.board[1],e.data.board[2],e.data.board[3],e.data.dir,e.data.depth),stateEvaled:Module._nodes()})");
}