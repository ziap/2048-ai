import {GameManager} from "./vendor/2048.min.js"

let game;
window.requestAnimationFrame(() => {
  game = new GameManager(4);
});

let aiRunning = false;

const workers = [
  new Worker("ai.js"),
  new Worker("ai.js"),
  new Worker("ai.js"),
  new Worker("ai.js")
];

let working = 0;
let bestMove, bestResult;
let startTime, totalMove;

for (let i = 0; i < 4; ++i) {
  workers[i].onmessage = ({data}) => {
    working--;
    if (data > bestResult) {
      bestResult = data;
      bestMove = i;
    }
    if (working == 0) {
      game.move(bestMove);
      totalMove++;
      if (game.over) stopAI();
      if (game.won) {
        game.keepPlaying = true;
        game.actuator.clearMessage();
      }
      if (aiRunning) step();
    }
  }
}

function currentState() {
  const result = new Uint16Array(4);
  for (let i = 0; i < 4; ++i) {
    for (let j = 0; j < 4; ++j) {
      const tile = game.grid.cells[j][i];
      if (tile) result[i] = result[i] | ((Math.log2(tile.value) & 0xf) << (12 - 4 * j));
    }
  }
  return result;
}

function step() {
  const board = currentState();
  bestResult = 0;
  working = 4;
  bestMove = 0 | 4 * Math.random();
  for (let i = 0; i < 4; ++i) workers[i].postMessage({board, dir: i});
}

function toggleAI() {}

function startAI() {
  totalMove = 0;
  startTime = Date.now();
  document.getElementsByClassName("ai-buttons")[1].textContent = "Stop";
  aiRunning = true;
  step();
  toggleAI = stopAI;

}

function stopAI() {
  const endTime = Date.now();
  console.log(`Time elapsed: ${(endTime - startTime) / 1000} seconds\nMoves taken: ${totalMove} moves\nSpeed: ${totalMove * 1000 / (endTime - startTime)} moves per second`);
  document.getElementsByClassName("ai-buttons")[1].textContent = "Start AI";
  aiRunning = false;
  toggleAI = startAI;
}

toggleAI = startAI;

document.querySelector("#ai-step").addEventListener('click', () => step())
document.querySelector("#ai-start").addEventListener('click', () => toggleAI())
