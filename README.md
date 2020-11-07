# 2048 AI
 An AI made for the game 2048.
 The AI can reach 16384 most of the time and sometime even reach 32768.

# Algorithm
 This AI is an Expectimax search run in parallel on your browser without any back-end server or browser control, so you can even run it on a mobile device.

 The AI uses 4 webworkers, each is a WebAssembly module compiled from C++ with Emscripten to perform the Expectimax search for each move available. The move with the highest result is chosen. Because the search is done in parallel and the workers use heavy optimizations like bitboard representation, lookup tables, the AI can search very deep in a short amount of time (default search depth is 7).

 I don't implement a Transposition Table to cache previously evaluated positions because evaluating a position multiple time is actually faster and more memory-efficient than caching that position and look it up later. The default depth is 7, but the AI has iterative deepening, meaning it will increase the depth if the AI didn't evaluate enough position. Not only the depth but the minimum position it has to evaluate also increases, so it'll think longer in critical scenarios, such as when it's about to make a new highest tile.

## Heuristic
 I came up with new heuristics for the evaluation function such as smoothness (making the board easier to merge), Floating tiles (prevent flat board),... but I can't tune the weights using mathematical optimization so I used the same heuristics in [this AI by Robert Xiao](https://github.com/nneonneo/2048-ai).

## Modification
 If you wan't to edit the search parameters or changing the evaluation function, the c++ source is available in this repo. You need to set up Emscripten first, you can download it [here](https://emscripten.org/docs/getting_started/downloads.html), make sure to add Emscripten to PATH. After modifying the source code, you can compile using the batch file (windows) or using this command:
```
em++ cpp/2048.cpp -o js/ai.js -s WASM=1 -O3 -s NO_EXIT_RUNTIME=1
```
 Then you can test the AI by running it on a [web server](https://developer.mozilla.org/en-US/docs/Learn/Common_questions/set_up_a_local_testing_server).

# License
 This app is licensed under the MIT license.