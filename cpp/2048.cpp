#include <iostream>
#include <iomanip>
#include <fstream>
#include <random>
#include <chrono>
#include "search.hpp"

int MaxRank(board_t s) {
    int maxrank = 0;
    while (s) {
        maxrank = std::max(maxrank, int(s & 0xf));
        s >>= 4;
    }
    return maxrank;
}

board_t AddRandomTile(board_t s) {
    int pos;
    do {
        pos = rand() % 16;
    } while ((s >> (4 * pos)) & 0xf);
    return s | (1ULL << (rand() % 10 == 0) << (4 * pos));
}

void PrintBoard(board_t s) {
    int board[16];
    for (int i = 0; i < 16; ++i) {
        board[i] = (s & 0xf);
        if (board[i]) board[i] = 1 << board[i];
        s >>= 4;
    }
    for (int i = 0; i < 16; ++i) {
        if (i % 4 == 0) std::cout << '\n';
        std::cout << std::setw(6) << board[i];
    }
    std::cout << '\n';
}

int BestMove(board_t s) {
    int best = rand() % 4;
    double max = 0;
    for (int i = 0; i < 4; ++i) {
        if (Move(s, i) == s) continue;
        double value = ExpectimaxSearch(s, i);
        if (value > max) {
            max = value;
            best = i;
        }
    }
    return best;
}

int main() {
    srand(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    int rate[5] = {0, 0, 0, 0, 0};
    for (int i = 0; i < 100; i++) {
        board_t board;
        board_t nextBoard = AddRandomTile(0);
        int rank = 0;
        bool gameOver = false;
        while (!gameOver) {
            board = AddRandomTile(nextBoard);
            int newRank = MaxRank(board);
            if (newRank > rank) {
                std::cout.flush();
                std::cout << '\r' << (1 << newRank);
                rank = newRank;
            }
            nextBoard = Move(board, BestMove(board));
            gameOver = (nextBoard == board); 
        }
        for (int j = 11; j <= rank; j++) rate[j - 11]++;
        std::cout << '\n';
    }
    std::ofstream fout("benchmark.txt");
    for (int i = 0; i < 5; i++) fout << '|' << std::setw(6) << (1 << (i + 11));
    fout << "|\n|------|------|------|------|------|\n";
    for (int i = 0; i < 5; i++) fout << '|' << std::setw(6) << rate[i];
    fout << "|\n";
}