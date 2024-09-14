cmake_minimum_required(VERSION 3.20) # Required for v2 of the presets schema
project(glutbrowser C)

FIND_PACKAGE(OpenGL REQUIRED)
find_package(freeglut REQUIRED PATHS freeglut/FreeGLUT)

add_executable(glutbrowser main.c)
target_include_directories(glutbrowser PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/freeglut/include")
target_link_libraries(glutbrowser FreeGLUT::freeglut_static)
