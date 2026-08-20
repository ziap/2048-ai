import {GameManager} from "../vendor/2048.min.js"

// Mirrors MEMORY_BYTES in build.zig. The module imports its memory so every
// worker can instantiate over the same one; a mismatch is a LinkError here.
const MEMORY_PAGES = 1024

const RELOAD_KEY = '2048-ai:coi-reload'

async function ensureIsolated() {
  if (window.crossOriginIsolated) {
    sessionStorage.removeItem(RELOAD_KEY)
    return true
  }

  if (!navigator.serviceWorker) return false
  if (sessionStorage.getItem(RELOAD_KEY)) return false

  try {
    await navigator.serviceWorker.register(new URL('../sw.js', import.meta.url))
    await navigator.serviceWorker.ready
  } catch {
    return false
  }

  sessionStorage.setItem(RELOAD_KEY, '1')
  location.reload()

  // The reload is async, so keep the caller from starting anything.
  await new Promise(() => {})
}

function createWorker(worker_url, config) {
  const worker = new Worker(worker_url, { type: 'module' })
  worker.postMessage(config)
  return new Promise((resolve, reject) => worker.addEventListener('message', e => {
    const msg = e.data
    if (msg != 'ready') reject(new Error(`Expected 'ready', got '${msg}'`))
    resolve(worker)
  }, { once: true }))
}

window.requestAnimationFrame(async () => {
  // Reloads the page if the worker had to be installed first, so nothing below
  // this line runs twice.
  await ensureIsolated()

  const game = new GameManager(4);
  let aiRunning = false

  if (typeof SharedArrayBuffer == 'undefined') {
    throw new Error('needs cross-origin isolation; serve over https:// or ' +
      'localhost so sw.js can install, or send COOP/COEP (see config.toml)')
  }

  const requested = new URLSearchParams(location.search).get('threads')
  const threads = Math.max(
    (requested == null ? navigator.hardwareConcurrency : Number(requested)) | 0, 1)

  const memory = new WebAssembly.Memory({
    initial: MEMORY_PAGES,
    maximum: MEMORY_PAGES,
    shared: true,
  })

  // Compiled once and instantiated per worker, so N workers don't each
  // recompile the module on startup.
  const module = await WebAssembly.compileStreaming(
    fetch(new URL('../zig-out/main.wasm', import.meta.url)),
  )

  // The pool parks before it touches anything the searcher builds, but every
  // worker is still handshaken before the first search goes out.
  await Promise.all(Array.from(
    { length: threads - 1 },
    () => createWorker('./js/pool-worker.js', { module, memory }),
  ))

  const worker = await createWorker('./js/worker.js', { module, memory })
  console.log(`Compute threads: ${threads}`)

  /** @type{Map<number, bigint>} */
  const log2Lut = new Map()
  for (let i = 1; i < 16; ++i) {
    log2Lut.set(1 << i, BigInt(i))
  }

  function currentState() {
    let result = 0n

    const { cells } = game.grid

    for (let i = 0; i < 4; ++i) {
      for (let j = 0; j < 4; ++j) {
        const tile = cells[j][i]
        result <<= 4n
        if (tile) result |= log2Lut.get(tile.value) ?? 15n
      }
    }
    return result;
  }

  const toggleButton = document.querySelector('#ai-toggle');

  /**
   * @param {boolean} restart 
   */
  function step(restart) {
    const board = currentState()
    worker.postMessage({ board, restart })
  }

  let randomDir = 0
  let totalMove, startTime

  worker.addEventListener('message', ({ data: dir }) => {
    randomDir = (randomDir + 1) % 4
    const finalDir = (dir == -1) ? randomDir : dir
    game.move(finalDir)
    totalMove += 1

    if (game.over) toggleAI(false)
    if (game.won) {
      game.keepPlaying = true
      game.actuator.clearMessage()
    }
    if (aiRunning) step(false)
  })

  function toggleAI(running) {
    if (running) {
      totalMove = 0
      startTime = Date.now()
      toggleButton.textContent = 'Stop'
      step(true)
    } else {
      const endTime = Date.now()
      console.log(`Time elapsed: ${(endTime - startTime) / 1000} seconds
Moves taken: ${totalMove} moves
Speed: ${totalMove * 1000 / (endTime - startTime)} moves/s`)
      toggleButton.textContent = 'Start AI'
    }
    aiRunning = running
  }

  document.querySelector("#ai-step").addEventListener('click', () => step(true))
  toggleButton.addEventListener('click', () => toggleAI(!aiRunning))
})
