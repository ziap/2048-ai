typedef unsigned long long board_t;
typedef unsigned short row_t;

int CountEmpty(board_t x)
{
    x |= (x >> 2) & 0x3333333333333333ULL;
    x |= (x >> 1);
    x = ~x & 0x1111111111111111ULL;
    x += x >> 32;
    x += x >> 16;
    x += x >>  8;
    x += x >>  4;
    return x & 0xf;
}

board_t Transpose(board_t s) {
    board_t a1 = s & 0xF0F00F0FF0F00F0FULL;
    board_t a2 = s & 0x0000F0F00000F0F0ULL;
    board_t a3 = s & 0x0F0F00000F0F0000ULL;
    board_t a = a1 | (a2 << 12) | (a3 >> 12);
    board_t b1 = a & 0xFF00FF0000FF00FFULL;
    board_t b2 = a & 0x00FF00FF00000000ULL;
    board_t b3 = a & 0x00000000FF00FF00ULL;
    return b1 | (b2 >> 24) | (b3 << 24);
}

row_t ReverseRow(row_t row) {
    return (row >> 12) | ((row >> 4) & 0x00F0) | ((row << 4) & 0x0F00) | (row << 12);
}

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

board_t Move(board_t s, int dir) {
    switch (dir) {
        case 0: return MoveUp(s);
        case 1: return MoveRight(s);
        case 2: return MoveDown(s);
        case 3: return MoveLeft(s);
        default: return s;
    }
}