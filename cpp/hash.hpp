#include <random>
#include <chrono>

class Hash
{
    public:
    Hash() {
        std::mt19937 mt(3141592654);
        std::uniform_int_distribution<int> distribution(0, 0x3fffff);
        for (int i = 0; i < 256; i++) zMap[i] = distribution(mt);
    }
    int Lookup(board_t board, float prob, int depth, float* score) {
        Entry entry = entries[ZHash(board)];
        if (entry.board == board && entry.prob >= prob && entry.depth >= depth) {
            *score = entry.score;
            return entry.moves;
        }
        return 0;
    }
    void Update(board_t board, float prob, int depth, float score, int moves) {
        Entry& entry = entries[ZHash(board)];
        entry.board = board;
        entry.prob = prob;
        entry.depth = depth;
        entry.score = score;
        entry.moves = moves;
    }
    void Clear() {
        for (int i = 0; i < 0x400000; ++i) entries[i].board = 0;
    }
    private:
    struct Entry {
        unsigned long long board;
        float prob;
        float score;
        int depth;
        int moves;
    };
    Entry entries[0x400000];
    int zMap[256];
    int ZHash(board_t x) {
        int value = 0;
        for (int i = 0; i < 16; ++i) {
            value ^= zMap[(i << 4) | (x & 0xf)];
            x >>= 4;
        }
        return value;
    }
};