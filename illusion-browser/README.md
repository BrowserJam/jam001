#illusion-browser

Steps to run:-

- Download and set up the Odin compiler from here: http://odin-lang.org/
- Run `odin build .` to build a binary or `odin run . -- path/to/html/file` to directly build and run
- Compiler will probably complain about the lack of cgltf and stb libraries on linux. Follow the instructions from the compiler to build them.

The program only accepts html files as the first argument
