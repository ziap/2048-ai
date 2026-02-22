# 2048 AI

An AI made for the game 2048. The AI can reach 16384 most of the time and
sometimes even reach 32768. Note, this is a newer and improved version of the
AI, rewritten in Zig. You can find the old C++ version
[here](https://github.com/ziap/2048-ai/tree/old-cpp)

## Algorithm

This AI is an Expectimax search run in parallel on your browser without any
back-end server or browser control. You can even run it on a mobile device!

The AI uses 4 web workers, each one is a WebAssembly module compiled from Zig
to perform the Expectimax search for each available move. The move with the
highest result is chosen. Because the search is done in parallel and the
workers use heavy optimizations like bitboard representation, lookup tables,...
the AI can search very deep, especially in difficult positions, very quickly.

## Benchmark

This repository also includes a console application to run the AI without the
overhead of the web platform. It also allows for reproducible benchmarking of
the AI playing multiple games in parallel. Here's the current benchmark
results: TBA

## Features

- 64-bit bitboard representation
- Table lookup for movement and evaluation
- Depth allocation using memory-constrained BFS
- Web version:
  - Root parallelism (WIP: subtree parallelism)
- Console version:
  - Game parallelism
  - Search budget configuration
  - Fully deterministic benchmark
- Memory optimizations:
  - No dynamic allocation during search
  - Console version: allocate everything at startup
  - Web version: only use stack and static memory
  - Cache-efficient data structures

## Usage

Get [Zig](https://ziglang.org/) version
[0.15.2](https://ziglang.org/download/#release-0.15.2), and compile everything
with optimization using the following command:

```sh
zig build --release=fast
```

Use `zig build -l` and `zig build -h` to customize the compilation. Run the
console application using:

```sh
zig-out/bin/2048 [options]
```

Available options:

```
  -i, --iter <u32>     Number of iterations (default: 1)
  -b, --budget <u32>   Processing budget (default: 524288)
  -t, --threads <u32>  Number of threads (default: auto)
  -s, --seed <bytes>   Seed for the PRNG (default: random)
  -h, --help           Display this help message
```

The web version is already hosted [here](https://ziap.github.io/2048-ai). For
hosting locally, just compile everything as shown above and use any HTTP
server, for example:

```sh
# Serve the app locally with your HTTP server of choice
python3 -m http.server 8080

# Launch the app in your browser of choice
firefox http://localhost:8080
```

# License

This project is licensed under the [MIT License](LICENSE).
