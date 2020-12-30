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
std::vector<double> resultTime;
std::vector<double> resultSpeed;

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
    unsigned long long tile = (1ULL << (rand() % 10 == 0));
    if (tile == 2) gen4tiles++;
    return s | (tile << empty[rand() % numEmpty]);
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
        board = AddRandomTile(AddRandomTile(0));
        gen4tiles = 0;
        int moves = 0;
        int maxTile = 0;
        auto start = std::chrono::high_resolution_clock::now();
        for (;;) {
            int best = rand() % 4;
            double max = 0;
            for (int i = 0; i < 4; ++i) {
                double result = search(board, i);
                if (result > max) {
                    max = result;
                    best = i;
                }
            }
            board_t newBoard = move(board, best);
            if (newBoard == board) break;
            else board = AddRandomTile(newBoard);
            moves++;
            int newMax = MaxRank(board);
            if (newMax > maxTile) {
                maxTile = newMax;
                if (maxTile >= 11) bigTiles[maxTile - 11]++;
                std::cout.flush();
                std::cout << "\rProgress: " << (1 << maxTile);
            }
        }
        std::cout << '\n';
        PrintBoard(board);
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count();
        std::cout << "------------------------\nDuration: " << (double)elapsed / 1000.0 << " seconds\nTotal moves: " << moves << "\naverage speed: " << (double)moves * 1000.0 / (double)elapsed << " Moves per second\n";
        int score = 0;
        while(board) {
            int rank = board & 0xf;
            score += (rank - 1) << rank;
            board >>= 4;
        }
        resultScore.push_back(score - 4 * gen4tiles);
        resultMoves.push_back(moves);
        resultTime.push_back((double)elapsed / 1000.0);
        resultSpeed.push_back((double)moves * 1000.0 / (double)elapsed);
    }
    std::ofstream fout("result.csv");
    for (int i = 0; i < 5; i++) fout << (1 << (i + 11)) << ',';
    fout << '\n';
    for (int i = 0; i < 5; i++) fout << (double)bigTiles[i] * 100.0 / (double)iterations << "%,";
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