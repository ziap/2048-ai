class Heuristic {
    private:
    double heurTable[65536];
    public:
    Heuristic(double SCORE_MONOTONICITY_POWER, double SCORE_MONOTONICITY_WEIGHT,
                   double SCORE_SUM_POWER, double SCORE_SUM_WEIGHT,
                   double SCORE_MERGES_WEIGHT, double SCORE_EMPTY_WEIGHT) {
        const double SCORE_LOST_PENALTY = 200000.0f;
        for (unsigned row = 0; row < 65536; ++row) {
            unsigned line[4] = {
                (row >>  0) & 0xf,
                (row >>  4) & 0xf,
                (row >>  8) & 0xf,
                (row >> 12) & 0xf
            };
            double sum = 0;
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

            double monotonicity_left = 0;
            double monotonicity_right = 0;
            for (int i = 1; i < 4; ++i) {
                if (line[i-1] > line[i]) {
                    monotonicity_left += pow(line[i-1], SCORE_MONOTONICITY_POWER) - pow(line[i], SCORE_MONOTONICITY_POWER);
                } else {
                    monotonicity_right += pow(line[i], SCORE_MONOTONICITY_POWER) - pow(line[i-1], SCORE_MONOTONICITY_POWER);
                }
            }

            heurTable[row] = SCORE_LOST_PENALTY +
                SCORE_EMPTY_WEIGHT * empty +
                SCORE_MERGES_WEIGHT * merges -
                SCORE_MONOTONICITY_WEIGHT * std::min(monotonicity_left, monotonicity_right) -
                SCORE_SUM_WEIGHT * sum;
        }
    }
    double ScoreHeuristic(board_t board) {
        return
            heurTable[(board >> 48) & 0xffff] +
            heurTable[(board >> 32) & 0xffff] +
            heurTable[(board >> 16) & 0xffff] +
            heurTable[board & 0xffff];
    }
};