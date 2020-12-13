# 2048 AI
 An AI made for the game 2048.
 The AI can reach 16384 most of the time and sometimes even reach 32768.

## Algorithm
 This AI is an Expectimax search run in parallel on your browser without any back-end server or browser control, so you can even run it on a mobile device.

 The AI uses 4 web workers, each is a WebAssembly module compiled from C++ with Emscripten to perform the Expectimax search for each move available. The move with the highest result is chosen.
 Because the search is done in parallel and the workers use heavy optimizations like bitboard representation, lookup tables, the AI can search very deep in a short amount of time (default search depth is 5).

## Performance
 The default search depth is 3, but you can increase to 7 or even 11. With the search depth of 3, the AI can easily reach 1000-1200 moves per second by pruning nodes with low chance and can get to 16384 47% of the time thanks to smart iterative deepening. With the search depth of 7, the AI runs at 50 moves per second and can get to 16384 95% of the time and even the 32768 tile 15% of the time, but because the AI runs on the web, it usually run 2 times slower so it's better to use a limited search depth for less performance consumption, especially on mobile devices.

## Heuristic
 Heuristics not only increase the strength of the AI but also direct the AI into positions that can be evaluated faster, which'll increase the speed of the AI significantly. I came up with new heuristics for the evaluation function such as smoothness (making the board easier to merge), floating tiles (preventing flat boards),... but I can't tune the weights using mathematical optimization so I used the same heuristics in [this AI by Robert Xiao](https://github.com/nneonneo/2048-ai).

## Modification
 If you want to edit the search parameters or change the evaluation function, the c++ source is available in this repo. You need to set up Emscripten first, you can download it [here](https://emscripten.org/docs/getting_started/downloads.html), make sure to add Emscripten to PATH. After modifying the source code, you can compile using the batch file (windows) or using this command:
```
em++ cpp/2048.cpp -o js/ai.js -s WASM=1 -O3 -s NO_EXIT_RUNTIME=1
```
 Then you can test the AI by running it on a web server. The simplest way is to make a simple python http server:
```
python -m http.server 8080
```
 and access the AI via http://localhost:8080. You can change 8080 to any port number.

# License
 This app is licensed under the MIT license.
