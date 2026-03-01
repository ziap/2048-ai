const module = await WebAssembly.instantiateStreaming(fetch('../zig-out/main.wasm'));

const { exports } = module.instance
exports.init()

addEventListener('message', ({ data: board }) => {
  postMessage(exports.search(board))
})

postMessage('ready')
