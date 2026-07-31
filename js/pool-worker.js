addEventListener('message', async ({ data }) => {
  const { memory } = data
  const module = /** @type{WebAssembly.Module} */(data.module)

  const instance = await WebAssembly.instantiate(module, { env: { memory } })
  const exports = /** @type{any} */(instance.exports)

  postMessage('ready')

  // Never returns: claims a stack, then parks on the batch epoch inside wasm.
  exports.poolWorker()
}, { once: true })
