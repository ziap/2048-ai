typedef unsigned long long board_t;
typedef unsigned short row_t;

int MaxRank(board_t s) {
    int maxrank = 0;
    for (;s;s>>=4) maxrank = std::max(maxrank, int(s & 0xf));
    return maxrank;
}

int CountDistinct(board_t b) {
    int mask = 0;
    while (b) {
        mask |= 1 << (b & 0xf);
        b >>= 4;
    }
    int count = 0;
    for (int i = 1; i < 16; i++) if (mask >> i & 1) {
        count++;
    }
    return count;
}

int CountEmpty(board_t b) {
    b = ~b;
    b &= b >> 2;
    b &= b >> 1;
    b &= 0x1111111111111111ull;
    b = (b * 0x1111111111111111ull) >> 60;
    return b;
}

board_t Transpose(board_t x) {
    board_t t;
    t = (x ^ (x >> 12)) & 0x0000f0f00000f0f0ull;
    x ^= t ^ (t << 12);
    t = (x ^ (x >> 24)) & 0x00000000ff00ff00ull;
    x ^= t ^ (t << 24);
    return x;
}

row_t ReverseRow(row_t row) {
    return (row >> 12) | ((row >> 4) & 0x00F0) | ((row << 4) & 0x0F00) | (row << 12);
}