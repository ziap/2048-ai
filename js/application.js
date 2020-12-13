// Wait till the browser is ready to render the game (avoids glitches)
var game;
window.requestAnimationFrame(function () {
    game = new GameManager(4, KeyboardInputManager, HTMLActuator, LocalStorageManager);
});

var aiRunning = false;

var workers = [
    new Worker("js/ai.js"),
    new Worker("js/ai.js"),
    new Worker("js/ai.js"),
    new Worker("js/ai.js")
];

var working = 0;
var bestMove, bestResult;
var startTime, totalMove;

for (let i = 0; i < 4; ++i) {
    workers[i].onmessage = function(e) {
        working--;
        if (e.data > bestResult) {
            bestResult = e.data;
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
    var result = new Uint16Array(4);
    for (var i = 0; i < 4; ++i) {
        for (var j = 0; j < 4; ++j) {
            var tile = game.grid.cells[j][i];
            if (tile) result[i] = result[i] | (Math.min(Math.log2(tile.value), 0xf) << (12 - 4 * j));
        }
    }
    return result;
}

function step() {
    var board = currentState();
    bestResult = 0;
    working = 4;
    bestMove = 0 | 4 * Math.random();
    for (var i = 0; i < 4; ++i) {
        workers[i].postMessage({
            board: board,
            dir: i,
        })
    }
}

function initAI() {
    startAI = () => {
        totalMove = 0;
        startTime = Date.now();
        document.getElementsByClassName("ai-buttons")[1].innerHTML = "Stop";
        aiRunning = true;
        step();
        startAI = stopAI;
    }
}


function stopAI() {
    var endTime = Date.now();
    console.log("Time elapsed: " + (endTime - startTime) / 1000 + " seconds"
        + "\nMoves taken: " + totalMove + " moves"
        + "\nSpeed: " + totalMove * 1000 / (endTime - startTime) + " moves per second");
    document.getElementsByClassName("ai-buttons")[1].innerHTML = "Start AI";
    aiRunning = false;
    initAI();
}

initAI();