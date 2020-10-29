/*
    Simulation for batch testing and future parameter tuning.
    Minimum depth is set to 1 (3 plies) and minimun state evaluation is set to 128 for faster run.
    Compile with gcc using "g++ simulator.cpp -o simulator.exe"
*/
#define NUM_OF_RUN 100
#define MIN_DEPTH 1
#define MIN_EVAL 128

#include "headers/board.hpp"

#include <stdio.h>
#include <stdlib.h>
#include <algorithm>

long long stateEvaled = 0;

heuristic score(4.0f, 47.0f, 3.5f, 11.0f, 700.0f, 270.0f, 1.0f, 0.0f);

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
    unsigned currentDepth = MIN_DEPTH;
    float result = Expectimax_spawnNode(newBoard, currentDepth);
    unsigned long long minState = MIN_EVAL;
    unsigned long long lastStates = 0;

    while ((stateEvaled < minState) && (stateEvaled > lastStates)) {
        currentDepth++;
        minState *= 2;
        lastStates = stateEvaled;
        stateEvaled = 0;
        result = Expectimax_spawnNode(newBoard, currentDepth);
    }
    return result;
}

int bestMove(board_t s) {
    float maxScore = 0;
    float move = rand() % 4;
    for (int i = 0; i < 4; i++) {
        float score = Expectimax_search(s, i);
        if (score > maxScore) {
            maxScore = score;
            move = i;
        }
    }
    return move;
}

int main() {
    freopen("result.txt", "w", stdout);
    srand(std::chrono::system_clock::now().time_since_epoch().count());
    for (int i = 0; i < NUM_OF_RUN; i++) {
        board_t board = addTile(addTile(0));
        for (;;) {
            board_t newBoard = move(board, bestMove(board));
            if (newBoard == board) break;
            else board = addTile(newBoard);
        }
        print(board);
    }
}