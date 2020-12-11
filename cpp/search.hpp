#include <cmath>
#include <algorithm>
#include "moveTable.hpp"
#include "revTable.hpp"
#include "board.hpp"
#include "heuristic.hpp"

//The key parameter controlling the strength and speed of the AI
#define MIN_DEPTH 1

Heuristic score(4.0f, 47.0f, 3.5f, 11.0f, 700.0f, 270.0f);
long long stateEvaled = 0;
double minProb;

double ExpectimaxMoveNode(board_t s, unsigned depth, double prob);
double ExpectimaxSpawnNode(board_t s, unsigned depth, double prob);

double ExpectimaxSpawnNode(board_t s, unsigned depth, double prob) {
    if (depth <= 0 || prob < minProb) return score.ScoreHeuristic(s) + score.ScoreHeuristic(Transpose(s));
    int emptyTiles = CountEmpty(s);
    prob /= emptyTiles;
    double expect = 0.0;
    for (int i = 0; i < 16; i++) {
        unsigned val = (s >> (60 - 4 * i)) & 0xf;
        if (val != 0) continue;
        expect += ExpectimaxMoveNode(s | (0x1ULL << (60 - 4 * i)), depth - 1, prob * 0.9) * 0.9;
        expect += ExpectimaxMoveNode(s | (0x2ULL << (60 - 4 * i)), depth - 1, prob * 0.1) * 0.1;
    }
    return expect / (double)emptyTiles;
}

double ExpectimaxMoveNode(board_t s, unsigned depth, double prob) {
    stateEvaled++;
    double max = 0;
    for (int i = 0; i < 4; i++) {
        board_t newBoard = Move(s, i);
        if (newBoard == s) continue;
        max = std::max(max, ExpectimaxSpawnNode(newBoard, depth, prob));
    }
    return max;
}

double ExpectimaxSearch(board_t s, int moveDir) {
    board_t newBoard = Move(s, moveDir);
    if (newBoard == s) return 0;
    stateEvaled = 0;
    unsigned currentDepth = MIN_DEPTH;
    minProb = 1.0 / (double)(1 << (2 * currentDepth + 5));
    double result = ExpectimaxSpawnNode(newBoard, currentDepth, 1);
    unsigned long long minState = 1 << (3 * currentDepth + 5);
    unsigned long long lastStates = 0;
    while ((stateEvaled < minState) && (stateEvaled > lastStates)) {
        currentDepth++;
        minProb = 1.0 / (double)(1 << (2 * currentDepth + 5));
        minState *= 2;
        lastStates = stateEvaled;
        stateEvaled = 0;
        result = ExpectimaxSpawnNode(newBoard, currentDepth, 1);
    }
    return result;
}