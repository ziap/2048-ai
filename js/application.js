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

var working = 0;
var bestResult = 0;
var currentDepth = 3;
var bestMove = 0;
var stateEvaled = 0;
var lastStateEvaled = 0;
var minStateEval = 40000;

//var startTime, moves;

for (let i = 0; i < 4; i++) {
    workers[i].onmessage = function(e) {
        working--;
        stateEvaled += e.data.stateEvaled;
        if (e.data.result > bestResult) {
            bestResult = e.data.result;
            bestMove = i;
        }
        if (working == 0) {
            if (stateEvaled >= minStateEval || stateEvaled <= lastStateEvaled) {
                if (bestResult > 0) game.move(bestMove);
                else game.move(0 | 4 * Math.random());
                if (game.over) stopAI();
                if (game.won) {
                    game.keepPlaying = true;
                    game.actuator.clearMessage();
                }
                currentDepth = 3;
                lastStateEvaled = 0;
                minStateEval = 40000;
                if (aiRunning) step();
            }
            else {
                currentDepth++;
                lastStateEvaled = stateEvaled;
                minStateEval *= 2;
                step();
            }
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
    stateEvaled = 0;
    bestResult = 0;
    for (var i = 0; i < 4; i++) {
        var board = currentState();
        workers[i].postMessage({
            board: board,
            dir: i,
            depth: currentDepth
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