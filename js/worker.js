;(async () => {
  const wasm = await WebAssembly.instantiateStreaming(fetch('../zig-out/main.wasm'))
  const exports = wasm.instance.exports

  exports.init()

  addEventListener('message', ({ data }) => {
    postMessage(exports.evaluate(data.board, data.dir))
  })

  postMessage('ready')
})()
