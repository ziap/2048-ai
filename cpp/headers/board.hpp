#include <iostream>
#include <iomanip>
#include <cmath>

typedef unsigned long long board_t;
typedef unsigned short row_t;

namespace board {
    board_t transpose(board_t s) {
        board_t a1 = s & 0xF0F00F0FF0F00F0FULL;
        board_t a2 = s & 0x0000F0F00000F0F0ULL;
        board_t a3 = s & 0x0F0F00000F0F0000ULL;
        board_t a = a1 | (a2 << 12) | (a3 >> 12);
        board_t b1 = a & 0xFF00FF0000FF00FFULL;
        board_t b2 = a & 0x00FF00FF00000000ULL;
        board_t b3 = a & 0x00000000FF00FF00ULL;
        return b1 | (b2 >> 24) | (b3 << 24);
    }
    row_t reverse_row(row_t row) {
        return (row >> 12) | ((row >> 4) & 0x00F0) | ((row << 4) & 0x0F00) | (row << 12);
    }
    void print(board_t s) {
        std::cout << "+-------+-------+-------+-------+\n";
        for (int i = 0; i < 16; i++) {
            unsigned val = pow(2, ((s >> (60 - 4 * i)) & 0xf));
            if (val > 1) std::cout << "| " << std::setw(5) << val << " ";
            else std::cout << "|       ";
            if (i % 4 == 3) std::cout << "|\n+-------+-------+-------+-------+\n";
        }
        std::cout << '\n';
    }
}