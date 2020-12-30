#include <cmath>
#include <algorithm>
#include "board.hpp"
#include "move.hpp"
#include "heuristic.hpp"

class Search {
    public:
    Search(int minDepth, double SCORE_MONOTONICITY_POWER, double SCORE_MONOTONICITY_WEIGHT,
        double SCORE_SUM_POWER, double SCORE_SUM_WEIGHT,
        double SCORE_MERGES_WEIGHT, double SCORE_EMPTY_WEIGHT) {
        MIN_DEPTH = minDepth;
        heuristic.BuildTable(SCORE_MONOTONICITY_POWER, SCORE_MONOTONICITY_WEIGHT, 
            SCORE_SUM_POWER, SCORE_SUM_WEIGHT, SCORE_MERGES_WEIGHT, SCORE_EMPTY_WEIGHT);
    }

    double operator()(board_t s, int moveDir) {
        board_t newBoard = move(s, moveDir);
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
    
    private:
    Heuristic heuristic;
    Move move;
    long long stateEvaled = 0;
    int MIN_DEPTH;
    double minProb;

    double ExpectimaxSpawnNode(board_t s, unsigned depth, double prob) {
        if (depth <= 0 || prob < minProb) return heuristic.ScoreHeuristic(s) + heuristic.ScoreHeuristic(Transpose(s));
        int emptyTiles = CountEmpty(s);
        prob /= emptyTiles;
        double expect = 0.0;
        for (int i = 0; i < 16; ++i) {
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
        for (int i = 0; i < 4; ++i) {
            board_t newBoard = move(s, i);
            if (newBoard == s) continue;
            max = std::max(max, ExpectimaxSpawnNode(newBoard, depth, prob));
        }
        return max;
    }
};
