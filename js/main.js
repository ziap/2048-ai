import {GameManager} from "../vendor/2048.min.js"

/**
 * @param {WebAssembly.Module} module
 * @param {number} workerCount 
 * @returns {Promise<Worker[]>}
 */
function createWorkers(module, workerCount) {
  /** @type {Promise<Worker>[]} */
  const workers = new Array(workerCount)
  for (let i = 0; i < workerCount; ++i) {
    const worker = new Worker('./js/worker.js')
    worker.postMessage({ module, dir: i })

    workers[i] = new Promise(resolve => {
      worker.addEventListener('message', e => {
        const msg = e.data
        if (msg != 'ready') throw new Error(`Expected 'ready', got ${msg}`)

        resolve(worker)
      }, { once: true })
    })
  }

  return Promise.all(workers)
}

window.requestAnimationFrame(async () => {
  const game = new GameManager(4);

  let aiRunning = false

  const module = await WebAssembly.compileStreaming(fetch('./zig-out/main.wasm'))
  const workers = await createWorkers(module, 4)

  let working = 0
  let bestMove, bestResult
  let startTime, totalMove

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
        if (tile) result |= log2Lut.get(tile.value)
      }
    }
    return result;
  }

  const toggleButton = document.querySelector('#ai-toggle');

  function step() {
    const board = currentState()
    bestResult = 0;
    working = 4;
    bestMove = 0 | 4 * Math.random()
    for (let i = 0; i < 4; ++i) workers[i].postMessage(board)
  }

  for (let i = 0; i < 4; ++i) {
    workers[i].addEventListener('message', ({data}) => {
      working--;
      if (data > bestResult) {
        bestResult = data;
        bestMove = i;
      }

      if (working == 0) {
        game.move(bestMove)
        totalMove++;
        if (game.over) toggleAI(false);
        if (game.won) {
          game.keepPlaying = true
          game.actuator.clearMessage()
        }
        if (aiRunning) step()
      }
    })
  }

  function toggleAI(running) {
    if (running) {
      totalMove = 0
      startTime = Date.now()
      toggleButton.textContent = 'Stop'
      step()
    } else {
      const endTime = Date.now()
      console.log(`Time elapsed: ${(endTime - startTime) / 1000} seconds
Moves taken: ${totalMove} moves
Speed: ${totalMove * 1000 / (endTime - startTime)} moves/s`)
      toggleButton.textContent = 'Start AI'
    }
    aiRunning = running
  }

  document.querySelector("#ai-step").addEventListener('click', step)
  toggleButton.addEventListener('click', () => toggleAI(!aiRunning))
})
