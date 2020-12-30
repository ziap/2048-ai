# 2048 AI
 An AI made for the game 2048.
 The AI can reach 16384 most of the time and sometimes even reach 32768.

## Algorithm
 This AI is an Expectimax search run in parallel on your browser without any back-end server or browser control, so you can even run it on a mobile device.

 The AI uses 4 web workers, each is a WebAssembly module compiled from C++ with Emscripten to perform the Expectimax search for each move available. The move with the highest result is chosen.
 Because the search is done in parallel and the workers use heavy optimizations like bitboard representation, lookup tables, the AI can search very deep in a short amount of time (default search depth is 5).

## Performance
 With the search depth of 3 ply, the AI can easily reach 500-800 moves per second by pruning nodes with low chance and can get to 16384 40% of the time thanks to smart iterative deepening. With the search depth of 7 ply, the AI runs at 20-50 moves per second and can get to 16384 95% of the time and even the 32768 tile 15% of the time, the web version of the AI use the search depth of 5 instead of 7 for better performance.

## Benchmark (Console application)
 With 3 ply search the AI can produce this result after 200 games (Intel® Core™ i5-8300H Processor):
 | % 32768 | % 16384 | % 8192 | % 4096 |
 |:-------:|:-------:|:------:|:------:|
 | 0.5 | 40.5 | 86 | 97.5 |

 Average results
 | Score | Moves/game | Moves/s | s/game |
 |:-----:|:----------:|:-------:|:------:|
 | 210606 | 8342 | 939 | 9 | 


## Heuristic
 Heuristics not only increase the strength of the AI but also direct the AI into positions that can be evaluated faster, which'll increase the speed of the AI significantly. I came up with new heuristics for the evaluation function such as smoothness (making the board easier to merge), floating tiles (preventing flat boards),... but I can't tune the weights using mathematical optimization so I used the same heuristics in [this AI by Robert Xiao](https://github.com/nneonneo/2048-ai).

## Usage
 I recommend using the AI in a linux environment.
 Compile the console application with a g++ compiler:
```sh
g++ cpp/2048.cpp -o 2048 -O3 -std=c++17
```
 Parameters:
 + **-d** - The search depth (1->4). Every depth is 2 ply + initial call so 1 is 3 ply and 3 is 7 ply
 + **-i** - Number of games to play for batch testing purpose.

 Example:
```sh
./2048 -d 3 -i 1 #Play 1 game with search depth of 3 (7 ply)
./2048 -d 1 -i 100 #Play 100 games with search depth of 1 (3 ply)
```

## Modify web version
 If you want to edit the search parameters or change the evaluation function, you need to set up Emscripten first, you can download it [here](https://emscripten.org/docs/getting_started/downloads.html), make sure to add Emscripten to PATH. After modifying the source code, you can compile using the batch file (windows) or using this command:
```sh
em++ cpp/2048-web.cpp -o js/ai.js -s WASM=1 -O3 -s NO_EXIT_RUNTIME=1
```
 Then you can test the AI by running it on a web server. The simplest way is to make a simple python http server:
```sh
python -m http.server 8080
```
 and access the AI via http://localhost:8080. You can change 8080 to any port number.

# License
 This app is licensed under the MIT license.
