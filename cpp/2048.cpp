#include <iostream>
#include <pthread.h>
#include <iomanip>
#include <fstream>
#include <random>
#include <chrono>
#include "search.hpp"

board_t board;
Search search(3, 4.0, 47.0, 3.5, 11.0, 700.0, 270.0);
Move move;
double threadResult[4];
struct threadData {
    board_t board;
    int moveDir;
};

void *threadSearch(void *threadID) {
    int tid = (intptr_t)threadID;
    threadResult[tid] = search(board, tid);
    pthread_exit(NULL);
}

int MaxRank(board_t s) {
    int maxrank = 0;
    while (s) {
        maxrank = std::max(maxrank, int(s & 0xf));
        s >>= 4;
    }
    return maxrank;
}

board_t AddRandomTile(board_t s) {
    int empty[16];
    int numEmpty = 0;
    for (int i = 0; i < 16; i++) if (!((s >> (4 * i)) & 0xf)) empty[numEmpty++] = 4 * i;
    return s | (1 << (rand() % 10 == 0) << empty[rand() % numEmpty]);
}

void PrintBoard(board_t s) {
    int board[16];
    for (int i = 0; i < 16; ++i) {
        board[i] = (s & 0xf);
        if (board[i]) board[i] = 1 << board[i];
        s >>= 4;
    }
    for (int i = 0; i < 16; ++i) {
        std::cout << std::setw(6) << board[i];
        if (i % 4 == 3) std::cout << '\n';
    }
}

int main() {
    srand(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    pthread_t threads[4];
    struct threadData td[4];
    for (int i = 0; i < 4; ++i) td[i].moveDir = i;
    board = AddRandomTile(AddRandomTile(0));
    int moves = 0;
    int maxTile = 0;
    auto start = std::chrono::high_resolution_clock::now();
    for (;;) {
        int best = rand() % 4;
        int max = 0;
        int i;
        for (i = 0; i < 4; ++i) {
            td[i].board = board;
            threadResult[i] = 0;
        }
        for (i = 0; i < 4; ++i) pthread_create(&threads[i], NULL, threadSearch, (void*)(intptr_t)i);
        for (i = 0; i < 4; ++i) pthread_join(threads[i], NULL);
        for (i = 0; i < 4; ++i) {
            if (threadResult[i] > max) {
                max = threadResult[i];
                best = i;
            }
        };
        board_t newBoard = move(board, best);
        if (newBoard == board) break;
        else board = AddRandomTile(newBoard);
        moves++;
        int newMax = MaxRank(board);
        if (newMax > maxTile) {
            maxTile = newMax;
            std::cout.flush();
            std::cout << "\rProgress: " << (1 << maxTile);
        }
    }
    std::cout << '\n';
    PrintBoard(board);
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count();
    std::cout << "------------------------\nDuration: " << (double)elapsed / 1000.0 << " seconds\nTotal moves: " << moves << "\naverage speed: " << (double)moves * 1000.0 / (double)elapsed << " Moves per second\n";
    pthread_exit(NULL);
}