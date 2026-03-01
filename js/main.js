import {GameManager} from "../vendor/2048.min.js"


window.requestAnimationFrame(async () => {
  const game = new GameManager(4);
  let aiRunning = false

  const worker = new Worker('./js/worker.js', { type: 'module' })
  await new Promise(resolve => {
    worker.addEventListener('message', e => {
      const msg = e.data
      if (msg != 'ready') throw new Error(`Expected 'ready', got ${msg}`)
      resolve()
    }, { once: true })
  })

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
    worker.postMessage(board)
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
    if (aiRunning) step()
  })

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
