import {GameManager} from "../vendor/2048.min.js"

/** @type{GameManager} */
let game;
window.requestAnimationFrame(() => {
  game = new GameManager(4);
});

/**
 * @param {number} workerCount 
 * @returns {Promise<Worker[]>}
 */
function createWorkers(workerCount) {
  /** @type {Promise<Worker>[]} */
  const workers = new Array(workerCount)
  for (let i = 0; i < workerCount; ++i) {
    const worker = new Worker('./js/worker.js')

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

let aiRunning = false

const workers = await createWorkers(4)

let working = 0
let bestMove, bestResult
let startTime, totalMove

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
      if (game.over) stopAI()
      if (game.won) {
        game.keepPlaying = true
        game.actuator.clearMessage()
      }
      if (aiRunning) step()
    }
  })
}

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

function step() {
  const board = currentState()
  bestResult = 0;
  working = 4;
  bestMove = 0 | 4 * Math.random()
  for (let i = 0; i < 4; ++i) workers[i].postMessage({ board, dir: i })
}

function toggleAI() {}

const toggleButton = document.querySelector('#ai-start');

function startAI() {
  totalMove = 0
  startTime = Date.now()
  toggleButton.textContent = 'Stop'
  aiRunning = true
  step()
  toggleAI = stopAI
}

function stopAI() {
  const endTime = Date.now()
  console.log(`Time elapsed: ${(endTime - startTime) / 1000} seconds
Moves taken: ${totalMove} moves
Speed: ${totalMove * 1000 / (endTime - startTime)} moves/s`)
  toggleButton.textContent = 'Start AI'
  aiRunning = false
  toggleAI = startAI
}

toggleAI = startAI

document.querySelector("#ai-step").addEventListener('click', () => step())
toggleButton.addEventListener('click', () => toggleAI())
