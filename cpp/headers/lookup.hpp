#include <bitset>
#include <vector>
#include <cmath>

typedef unsigned long long board_t;
typedef unsigned short row_t;

class lookup {
    private:
    float heurTable[65536];
    //std::bitset<65536> loseTable;
    public:
    lookup(std::vector<float> parameters) {
        const float SCORE_LOST_PENALTY = 200000.0f;
        const float SCORE_MONOTONICITY_POWER = parameters[0];
        const float SCORE_MONOTONICITY_WEIGHT = parameters[1];
        const float SCORE_SUM_POWER = parameters[2];
        const float SCORE_SUM_WEIGHT = parameters[3];
        const float SCORE_MERGES_WEIGHT = parameters[4];
        const float SCORE_EMPTY_WEIGHT = parameters[5]; 
        const float SCORE_DIFF_POWER = parameters[6];
        const float SCORE_DIFF_WEIGHT = parameters[7];
        for (unsigned row = 0; row < 65536; ++row) {
            unsigned line[4] = {
                (row >>  0) & 0xf,
                (row >>  4) & 0xf,
                (row >>  8) & 0xf,
                (row >> 12) & 0xf
            };
            float sum = 0;
            int empty = 0;
            int merges = 0;

            int prev = 0;
            int counter = 0;
            for (int i = 0; i < 4; ++i) {
                int rank = line[i];
                sum += pow(rank, SCORE_SUM_POWER);
                if (rank == 0) {
                    empty++;
                } else {
                    if (prev == rank) {
                        counter++;
                    } else if (counter > 0) {
                        merges += 1 + counter;
                        counter = 0;
                    }
                    prev = rank;
                }
            }
            if (counter > 0) {
                merges += 1 + counter;
            }

            float monotonicity_left = 0;
            float monotonicity_right = 0;
            float diff = 0;
            for (int i = 1; i < 4; ++i) {
                if (line[i-1] > line[i]) {
                    monotonicity_left += pow(line[i-1], SCORE_MONOTONICITY_POWER) - pow(line[i], SCORE_MONOTONICITY_POWER);
                } else {
                    monotonicity_right += pow(line[i], SCORE_MONOTONICITY_POWER) - pow(line[i-1], SCORE_MONOTONICITY_POWER);
                }
                diff += fabs(pow(line[i - 1], SCORE_DIFF_POWER) - pow(line[i], SCORE_DIFF_POWER));
            }

            heurTable[row] = SCORE_LOST_PENALTY +
                SCORE_EMPTY_WEIGHT * empty +
                SCORE_MERGES_WEIGHT * merges -
                SCORE_MONOTONICITY_WEIGHT * std::min(monotonicity_left, monotonicity_right) -
                SCORE_DIFF_WEIGHT * diff - 
                SCORE_SUM_WEIGHT * sum;

            //loseTable[row] = (empty + merges) == 0;
        }
    }
    /*bool losing(board_t board) {
        return
            loseTable[(board >> 48) & 0xffff] &&
            loseTable[(board >> 32) & 0xffff] &&
            loseTable[(board >> 16) & 0xffff] &&
            loseTable[board & 0xffff];
    }*/
    float heuristic(board_t board) {
        return
            heurTable[(board >> 48) & 0xffff] +
            heurTable[(board >> 32) & 0xffff] +
            heurTable[(board >> 16) & 0xffff] +
            heurTable[board & 0xffff];
    } 
};