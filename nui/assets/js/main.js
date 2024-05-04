window.addEventListener("message", function(ev) {
    var event = ev.data
    if (event.type == "playSound") {
        var audio = new Audio("assets/sounds/" + event.sound)
        audio.volume = 0.2
        audio.play()
        audio.addEventListener("ended", function() {
            audio.remove();
        });
    }
})