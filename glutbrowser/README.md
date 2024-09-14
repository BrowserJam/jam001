# GLUTBrowser - Made with only OpenGL and GLUT using C*

*For now, I am using only C but may switch to C-style C++*

## Building (Windows)

You must have VS2022, git (of course), and CMake. You can also probably build with GCC in MinGW, or Clang... if you have that installed then you can just change generators in the presets.

With the repo checked out, from this directory, run
```
git submodule update;
cd freeglut; cmake .; cmake --build .; cd ..;
cmake --preset=win-msvc-debug .;
```
