# JellyNet

JellyNet is my attempt at writing a browser for this jam (get it?). Here's the
best result I was able to get within time:

![JellyNet](assets/demo.png)

## Building / Running

Simply run `cargo build` or `cargo run` in the root directory of the project. I
love rust.

## TODO

If I had more time, I would have liked to really fix the layout engine in
general, it's basically hardcoded for this exact webpage and I doubt most other
webpages will work with it at all.

Frankly, the whole browser is kind of hard-coded for this webpage, and I would
have liked to make it more general. Seems like the parser fails on basically any
"real" html but I'm sure it's just a bunch of edgecases that I could fix.

I would also have liked to implement some chrome because right now it's just a
stupid simple browser engine.
