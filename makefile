all:
	g++ -std=c++17 -O3 -o 2048 cpp/2048.cpp
web:
	em++ cpp/2048-web.cpp -o js/ai.js -s WASM=1 -O3 -s NO_EXIT_RUNTIME=1 -s INITIAL_MEMORY=134217728
clean:
	rm -f 2048 result.csv