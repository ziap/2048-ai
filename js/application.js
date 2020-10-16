// Wait till the browser is ready to render the game (avoids glitches)                  //
var game;                                                                               //
window.requestAnimationFrame(function () {                                              //
    game = new GameManager(4, KeyboardInputManager, HTMLActuator, LocalStorageManager); //
});                                                                                     //
                                                                                        //
//////////////////////////////////////////////////////////////////////////////////////////

var aiRunning = false;

var workers = [
    new Worker("js/ai.js"),
    new Worker("js/ai.js"),
    new Worker("js/ai.js"),
    new Worker("js/ai.js")
];
working = 0;
workerResults = new Float32Array(4);

//var startTime, moves;

for (let i = 0; i < 4; i++) {
    workers[i].onmessage = function(e) {
        working--;
        workerResults[i] = e.data;
        if (working == 0) {
            var bestMove = 0, bestResult = 0;
            for (var j = 0; j < 4; j++) {
                if (workerResults[j] > bestResult) {
                    bestResult = workerResults[j];
                    bestMove = j;
                }
            }
            if (bestResult > 0) game.move(bestMove);
            else game.move(Math.floor(Math.random() * 4));
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
    for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
            var tile = game.grid.cells[j][i];
            if (tile) result[i] = result[i] | (Math.min(Math.log2(tile.value), 0xf) << (12 - 4 * j));
        }
    }
    return result;
}

function step() {
    working = 4;
    //moves++;
    workerResults = new Float32Array(4);
    for (var i = 0; i < 4; i++) {
        var board = currentState();
        workers[i].postMessage({
            board: board,
            dir: i
        })
    }
}

function initAI() {
    startAI = () => {
        //startTime = Date.now();
        //moves = 0;
        document.getElementsByClassName("ai-buttons")[1].innerHTML = "Stop";
        aiRunning = true;
        step();
        startAI = stopAI;
    }
}


function stopAI() {
    //var secs = (Date.now() - startTime) / 1000;
    //console.log("Total time: " + Math.floor(secs / 60) + " minutes " + Math.floor(secs) % 60 + " seconds\nTotal moves: "+ moves + "\nSpeed: " + moves / secs + " moves per second");
    document.getElementsByClassName("ai-buttons")[1].innerHTML = "Start AI";
    aiRunning = false;
    initAI();
}

initAI();