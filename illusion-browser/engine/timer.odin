package zephr

import "core:fmt"
import "core:time"

TimerState :: enum {
    RUNNING,
    PAUSED,
    STOPPED,
}

Timer :: struct {
    start:    f64,
    elapsed:  f64,
    duration: f32,
    state:    TimerState,
}

@(private)
TIMER: time.Stopwatch

@(private)
start_internal_timer :: proc() {
    time.stopwatch_start(&TIMER)
}

get_time :: proc() -> time.Duration {
    return time.stopwatch_duration(TIMER)
}

start_timer :: proc(timer: ^time.Stopwatch) {
    time.stopwatch_start(timer)
}

// TODO: incomplete
