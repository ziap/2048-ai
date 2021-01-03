#include <iostream>
#include <iomanip>
#include <fstream>
#include <random>
#include <chrono>
#include <cstdlib>
#include <getopt.h>
#include "search.hpp"

board_t board;
Move move;

int gen4tiles = 0;

int bigTiles[5]{0,0,0,0,0};

std::vector<int> resultScore;
std::vector<int> resultMoves;
std::vector<float> resultTime;
std::vector<float> resultSpeed;

int MaxRank(board_t s) {
    int maxrank = 0;
    for (;s;s>>=4) maxrank = std::max(maxrank, int(s & 0xf));
    return maxrank;
}

board_t AddRandomTile(board_t s) {
    int empty[16];
    int numEmpty = 0;
    board_t tmp = s;
    for (int i = 0; i < 16; i++) {
        if (!(tmp & 0xf)) empty[numEmpty++] = 4 * i;
        tmp >>= 4;
    }
    unsigned long long tile = (1ULL << (rand() % 10 == 0));
    if (tile == 2) ++gen4tiles;
    return s | (tile << empty[rand() % numEmpty]);
}

void PrintBoard(board_t s) {
    int board[16];
    int i = 0;
    for (;s;s>>=4) {
        i++;
        if (s & 0xf) std::cout << std::setw(6) << (1 << (s & 0xf));
        else std::cout << "      ";
        if (!(i % 4)) std::cout << '\n';
    }
}

int main(int argc, char* argv[]) {
    srand(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    int depth = 1, iterations = 1;
    int c;
    while ((c = getopt(argc, argv, "d:i:")) != -1) {
        switch (c)
        {
        case 'd':
            depth = atoi(optarg);
            break;
        
        case 'i':
            iterations = atoi(optarg);
            break;
        }
    }
    Search search(depth, 4.0, 47.0, 3.5, 11.0, 700.0, 270.0);
    for (int game = 1; game <= iterations; ++game) {
        std::cout << "Running game " << game << "/" << iterations <<'\n';
        gen4tiles = 0;
        board = AddRandomTile(AddRandomTile(0));
        hash.Clear();
        int moves = 0;
        int maxTile = 0;
        auto start = std::chrono::high_resolution_clock::now();
        for (;;) {
            int best = rand() % 4;
            float max = 0;
            for (int i = 0; i < 4; ++i) {
                float result = search(board, i);
                if (result > max) {
                    max = result;
                    best = i;
                }
            }
            board_t newBoard = move(board, best);
            if (newBoard == board) break;
            else board = AddRandomTile(newBoard);
            ++moves;
            int newMax = MaxRank(board);
            if (newMax > maxTile) {
                maxTile = newMax;
                if (maxTile >= 11) ++bigTiles[maxTile - 11];
                std::cout << "Progress: " << (1 << maxTile) << '\r';
                std::cout.flush();
            }
        }
        std::cout << '\n';
        PrintBoard(board);
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count();
        std::cout << "------------------------\nDuration: " << (float)elapsed / 1000.0 << " seconds\nTotal moves: " << moves << "\nAverage speed: " << (float)moves * 1000.0 / elapsed << " moves per second\n";
        int score = 0;
        while(board) {
            int rank = board & 0xf;
            score += (rank - 1) << rank;
            board >>= 4;
        }
        resultScore.push_back(score - 4 * gen4tiles);
        resultMoves.push_back(moves);
        resultTime.push_back((float)elapsed / 1000.0);
        resultSpeed.push_back((float)moves * 1000.0 / elapsed);
    }
    std::ofstream fout("result.csv");
    for (int i = 0; i < 5; ++i) fout << (1 << (i + 11)) << ',';
    fout << '\n';
    for (int i = 0; i < 5; ++i) fout << (float)bigTiles[i] * 100.0 / iterations << "%,";
    fout << "\n,\nGame,";
    for (int i = 1; i <= iterations; ++i) fout << i << ',';
    fout << "\nScore,";
    for (auto i : resultScore) fout << i << ',';
    fout << "\nMoves,";
    for (auto i : resultMoves) fout << i << ',';
    fout << "\nTime,";
    for (auto i : resultTime) fout << i << ',';
    fout << "\nSpeed,";
    for (auto i : resultSpeed) fout << i << ',';
    fout << '\n';
}
