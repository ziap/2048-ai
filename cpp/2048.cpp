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

std::string Progress(board_t s) {
    int WIDTH = 25;
    int sum = 0;
    for (board_t tmp = s; tmp; tmp >>=4) sum += (1 << (tmp & 0xf));
    int max = (1 << MaxRank(s));
    sum -= max;
    float progress = std::min(std::max((float)sum / (float)max, 0.0f), 1.0f);
    int wholeWidth = progress * WIDTH;
    std::string parts[8] = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉"};
    std::string partChar = parts[int(fmod(progress * WIDTH, 1.0) * 8.0)];
    if ((WIDTH - wholeWidth - 1) < 0) partChar = "";
    std::string bar;
    bar.push_back('[');
    for (int i = 0; i < wholeWidth; i++) bar += "█";
    bar += partChar;
    for (int i = 0; i < WIDTH - wholeWidth - 1; i++) bar.push_back(' ');
    bar.push_back(']');
    return bar;
}

int main(int argc, char* argv[]) {
    std::ios_base::sync_with_stdio(false);
    srand(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    int depth = 1, iterations = 1;
    bool detailed = false;
    int c;
    while ((c = getopt(argc, argv, "d:i:p")) != -1) {
        switch (c)
        {
        case 'd':
            depth = atoi(optarg);
            break;
        
        case 'i':
            iterations = atoi(optarg);
            break;
        case 'p':
            detailed = true;
            break;
        }
    }
    Search search(depth);
    for (int game = 1; game <= iterations; ++game) {
        std::cout << "Running game " << game << "/" << iterations <<'\n';
        hash.CLear();
        gen4tiles = 0;
        board = AddRandomTile(AddRandomTile(0));
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
                if (!detailed) {
                    std::cout << "Progress: " << (1 << maxTile) << '\r';
                    std::cout.flush();
                }
            }
            if (detailed) {
                std::cout << "Progress:" << std::setw(6) << (1 << maxTile) << ' ' << Progress(board) << ' ' << (1 << (maxTile + 1)) << '\r';
                std::cout.flush();
            }
        }
        std::cout << '\n';
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count();
        int score = 0;
        while(board) {
            int rank = board & 0xf;
            score += (rank - 1) << rank;
            board >>= 4;
        }
        resultScore.push_back(score - 4 * gen4tiles);
        resultMoves.push_back(moves);
        resultTime.push_back((float)elapsed / 1000.0);
        resultSpeed.push_back((float)moves * 1000.0 / (float)elapsed);
    }
    std::ofstream fout("result.csv");
    for (int i = 0; i < 5; ++i) fout << (1 << (i + 11)) << ',';
    fout << '\n';
    for (int i = 0; i < 5; ++i) fout << (float)bigTiles[i] * 100.0 / (float)iterations << "%,";
    fout << "\n,\nGame,Score,Moves,Time,Speed\n";
    float sumScore = 0, sumMoves = 0, sumTime = 0, sumSpeed = 0;
    for (int i = 0; i < iterations; ++i) {
        fout << i + 1 << ',' << resultScore[i] << ',' << resultMoves[i] << ',' << resultTime[i] << ',' << resultSpeed[i] << '\n';
        sumScore += resultScore[i];
        sumMoves += resultMoves[i];
        sumTime += resultTime[i];
        sumSpeed += resultSpeed[i];
    }
    fout << "Average" << ',' << sumScore / iterations << ',' << sumMoves / iterations << ',' << sumTime / iterations << ',' << sumSpeed / iterations;
}
