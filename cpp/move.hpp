class Move {
    public:
    Move() {
        for (unsigned row = 0; row < 65536; ++row) {
            unsigned line[4] = {
                (row >>  0) & 0xf,
                (row >>  4) & 0xf,
                (row >>  8) & 0xf,
                (row >> 12) & 0xf
            };
            int farthest = 3;
            bool merged = false;
            for (int i = 3; i >= 0; --i) {
                if (!line[i]) continue;
                if (!merged && farthest < 3 && line[i] == line[farthest + 1]) {
                    ++line[farthest + 1];
                    line[i] = 0;
                    merged = true;
                }
                else if (farthest == i) --farthest;
                else {
                    line[farthest--] = line[i];
                    line[i] = 0;
                    merged = false;
                }
            }
            moveTable[row] = line[0] | (line[1] << 4) | (line[2] << 8) | (line[3] << 12);
            revTable[ReverseRow(row)] = ReverseRow(moveTable[row]);
        }
    }
    board_t operator()(board_t s, int dir) {
        switch (dir) {
            case 0: return MoveUp(s);
            case 1: return MoveRight(s);
            case 2: return MoveDown(s);
            case 3: return MoveLeft(s);
            default: return s;
        }
    }
    private:
    row_t moveTable[65536];
    row_t revTable[65536];
    board_t MoveLeft(board_t s) {
        return (board_t(moveTable[s & 0xffff]) |
           (board_t(moveTable[(s >> 16) & 0xffff]) << 16) |
           (board_t(moveTable[(s >> 32) & 0xffff]) << 32) |
           (board_t(moveTable[(s >> 48) & 0xffff]) << 48));
    }

    board_t MoveRight(board_t s) {
        return (board_t(revTable[s & 0xffff]) |
           (board_t(revTable[(s >> 16) & 0xffff]) << 16) |
           (board_t(revTable[(s >> 32) & 0xffff]) << 32) |
           (board_t(revTable[(s >> 48) & 0xffff]) << 48));
    }

    board_t MoveUp(board_t s) {
        return Transpose(MoveLeft(Transpose(s)));
    }

    board_t MoveDown(board_t s) {
        return Transpose(MoveRight(Transpose(s)));
    }
};