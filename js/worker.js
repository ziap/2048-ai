addEventListener('message', async ({ data }) => {
  const { memory } = data
  const module = /** @type{WebAssembly.Module} */(data.module)

  const instance = await WebAssembly.instantiate(module, { env: { memory } })
  const exports = /** @type{any} */(instance.exports)

  // Builds the tables the whole pool shares. Nothing else touches them until
  // main has seen every worker's 'ready'.
  exports.init()

  // search() runs the batch protocol itself: it publishes the frontier, works
  // the queue alongside the pool and blocks until the last task lands.
  addEventListener('message', ({ data: board }) => postMessage(exports.search(board)))

  postMessage('ready')
}, { once: true })
