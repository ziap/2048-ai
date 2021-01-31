class Heuristic {
    private:
    float heurTable[65536];
    float ScoreHeuristic(board_t board) {
        return
            heurTable[(board >> 48) & 0xffff] +
            heurTable[(board >> 32) & 0xffff] +
            heurTable[(board >> 16) & 0xffff] +
            heurTable[board & 0xffff];
    }
    public:
    Heuristic() {
        const float SCORE_LOST_PENALTY = 200000.0f;
        const float SCORE_MONOTONICITY_POWER = 4.0f;
        const float SCORE_MONOTONICITY_WEIGHT = 47.0f;
        const float SCORE_SUM_POWER = 3.5f;
        const float SCORE_SUM_WEIGHT = 11.0f;
        const float SCORE_MERGES_WEIGHT = 700.0f;
        const float SCORE_EMPTY_WEIGHT = 270.0f;
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
                if (!rank) ++empty;
                else {
                    if (prev == rank) ++counter;
                    else if (counter > 0) {
                        merges += 1 + counter;
                        counter = 0;
                    }
                    prev = rank;
                }
            }
            if (counter > 0) merges += 1 + counter;

            float monotonicity_left = 0;
            float monotonicity_right = 0;
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
    float operator() (board_t s) {
        return ScoreHeuristic(s) + ScoreHeuristic(Transpose(s));
    }
    static constexpr float LOSE_PENALTY = 0;
};