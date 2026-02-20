;addEventListener('message', async ({ data: { module, dir } }) => {
  const { exports } = await WebAssembly.instantiate(module)

  exports.init()

  addEventListener('message', ({ data: board }) => {
    postMessage(exports.evaluate(board, dir))
  })

  postMessage('ready')
}, { once: true })
