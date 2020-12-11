#include <emscripten.h>
#include "search.hpp"

#ifdef __cplusplus
extern "C" {
#endif
double EMSCRIPTEN_KEEPALIVE jsWork(row_t row1, row_t row2, row_t row3, row_t row4, int dir) {
    return ExpectimaxSearch((board_t(row1) << 48) | (board_t(row2) << 32) | (board_t(row3) << 16) | board_t(row4), dir);
}
#ifdef __cplusplus
}
#endif

int main() {
    emscripten_run_script("onmessage=e=>postMessage(Module._jsWork(e.data.board[0],e.data.board[1],e.data.board[2],e.data.board[3],e.data.dir))");
}