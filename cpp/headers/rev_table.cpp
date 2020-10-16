#include <fstream>
#include "moveTable.hpp"
#include "board.hpp"

unsigned short revTable[65536];

int main() {
    std::ofstream fout("revTable.hpp");
    for (unsigned row = 0; row < 65536; row++)
        revTable[board::reverse_row(row)] = board::reverse_row(moveTable[row]);
    fout << "unsigned short revTable[65536] = {";
    for (unsigned row = 0; row < 65535; row++) fout << revTable[row] << ", ";
    fout << revTable[65535] << "};";
}
